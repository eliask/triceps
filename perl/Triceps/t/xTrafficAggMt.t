#
# (C) Copyright 2011-2013 Sergey A. Babkin.
# This file is a part of Triceps.
# See the file COPYRIGHT for the copyright notice and license information
#
# An example of traffic accounting aggregated to multiple levels,
# as a multithreaded pipeline.

#########################

use ExtUtils::testlib;

use Test;
BEGIN { plan tests => 2 };
use Triceps;
use Triceps::X::TestFeed qw(:all);
use Carp;
ok(1); # If we made it this far, we're ok.

use strict;

#########################
# This version of aggregation keeps updating the hourly and daily stats
# as the data comes in, on every packet (unlike xTrafficAgg.t that does that
# only at the end of the hour or day).
# It shows how each level can be split into a separate thread, to pipeline the
# computational load.

package Traffic1;

use Carp;
use Triceps::X::TestFeed qw(:all);

# Read the data and control commands from STDIN for the pipeline.
# The output is sent to the nexus "data".
# Also responsible for defining the control labels in the same nexus:
#   packet - the data
#   print - strings for printing at the end of pipeline
#   dumprq - dump requests to the elements of the pipeline
# Options inherited from Triead::start.
sub ReaderMain # (@opts)
{
	my $opts = {};
	Triceps::Opt::parse("traffic main", $opts, {@Triceps::Triead::opts}, @_);
	my $owner = $opts->{owner};
	my $unit = $owner->unit();

	my $rtPacket = Triceps::RowType->new(
		time => "int64", # packet's timestamp, microseconds
		local_ip => "string", # string to make easier to read
		remote_ip => "string", # string to make easier to read
		local_port => "int32", 
		remote_port => "int32",
		bytes => "int32", # size of the packet
	) or confess "$!";

	my $rtPrint = Triceps::RowType->new(
		text => "string", # the text to print (including \n)
	) or confess "$!";

	my $rtDumprq = Triceps::RowType->new(
		what => "string", # identifies, what to dump
	) or confess "$!";

	my $faOut = $owner->makeNexus(
		name => "data",
		labels => [
			packet => $rtPacket,
			print => $rtPrint,
			dumprq => $rtDumprq,
		],
		import => "writer",
	);

	my $lbPacket = $faOut->getLabel("packet");
	my $lbPrint = $faOut->getLabel("print");
	my $lbDumprq = $faOut->getLabel("dumprq");

	$owner->readyReady();

	while(&readLine) {
		chomp;
		# print the input line, as a debugging exercise
		$unit->makeArrayCall($lbPrint, "OP_INSERT", "> $_\n");

		my @data = split(/,/); # starts with a command, then string opcode
		my $type = shift @data;
		if ($type eq "new") {
			$unit->makeArrayCall($lbPacket, @data);
		} elsif ($type eq "dump") {
			$unit->makeArrayCall($lbDumprq, "OP_INSERT", $data[0]);
		} else {
			$unit->makeArrayCall($lbPrint, "OP_INSERT", "Unknown command '$type'\n");
		}
		$owner->flushWriters();
	}

	{
		# drain the pipeline before shutting down
		my $ad = Triceps::AutoDrain::makeShared($owner);
		$owner->app()->shutdown();
	}
}

# compute an hour-rounded timestamp (in microseconds)
sub hourStamp # (time)
{
	return $_[0]  - ($_[0] % (1000*1000*3600));
}

# Read and pass through the input, also:
#   * keep the raw data
#   * aggregate the hourly stats from it,
#   * send the aggregated data
#   * send the dump of the kept raw data on request
# The output is sent to the nexus "data".
# The added labels in the nexus:
#   hourly - the aggregatoed hourly data
#   dumpPacket - dump of the kept raw packet data
#
# Options are inherited from Triead::start, plus:
#   from => "thread/nexus"
#   The input nexus name.
sub RawToHourlyMain # (@opts)
{
	my $opts = {};
	Triceps::Opt::parse("traffic main", $opts, {
		@Triceps::Triead::opts,
		from => [ undef, \&Triceps::Opt::ck_mandatory ],
	}, @_);
	my $owner = $opts->{owner};
	my $unit = $owner->unit();

	# The current hour stamp that keeps being updated;
	# any aggregated data will be propagated when it is in the
	# current hour (to avoid the propagation of the aggregator clearing).
	my $currentHour;

	my $faIn = $owner->importNexus(
		from => $opts->{from},
		as => "input",
		import => "reader",
	);

	# the full stats for the recent time
	my $ttPackets = Triceps::TableType->new($faIn->getLabel("packet")->getRowType())
		->addSubIndex("byHour", 
			Triceps::IndexType->newPerlSorted("byHour", undef, sub {
				return &hourStamp($_[0]->get("time")) <=> &hourStamp($_[1]->get("time"));
			})
			->addSubIndex("byIP", 
				Triceps::IndexType->newHashed(key => [ "local_ip", "remote_ip" ])
				->addSubIndex("group",
					Triceps::IndexType->newFifo()
				)
			)
		)
	or confess "$!";

	# type for a periodic summary, used for hourly, daily etc. updates
	my $rtSummary;

	Triceps::SimpleAggregator::make(
		tabType => $ttPackets,
		name => "hourly",
		idxPath => [ "byHour", "byIP", "group" ],
		result => [
			# time period's (here hour's) start timestamp, microseconds
			time => "int64", "last", sub {&hourStamp($_[0]->get("time"));},
			local_ip => "string", "last", sub {$_[0]->get("local_ip");},
			remote_ip => "string", "last", sub {$_[0]->get("remote_ip");},
			# bytes sent in a time period, here an hour
			bytes => "int64", "sum", sub {$_[0]->get("bytes");},
		],
		saveRowTypeTo => \$rtSummary,
	);

	$ttPackets->initialize() or confess "$!";
	my $tPackets = $unit->makeTable($ttPackets, 
		&Triceps::EM_CALL, "tPackets") or confess "$!";

	# Filter the aggregator output to match the current hour.
	my $lbHourlyFiltered = $unit->makeDummyLabel($rtSummary, "hourlyFiltered");
	$tPackets->getAggregatorLabel("hourly")->makeChained("hourlyFilter", undef, sub {
		if ($_[1]->getRow()->get("time") == $currentHour) {
			$unit->call($lbHourlyFiltered->adopt($_[1]));
		}
	});

	# It's important to connect the pass-through data first,
	# before chaining anything to the labels of the faIn, to
	# make sure that any requests and raw inputs get through before
	# our reactions to them.
	my $faOut = $owner->makeNexus(
		name => "data",
		labels => [
			$faIn->getFnReturn()->getLabelHash(),
			hourly => $lbHourlyFiltered,
			dumpPackets => $tPackets->getDumpLabel(),
		],
		import => "writer",
	);

	# update the notion of the current hour before the table
	$faIn->getLabel("packet")->makeChained("updateHour", undef, sub {
		$currentHour = &hourStamp($_[1]->getRow()->get("time"));
	});
	$faIn->getLabel("packet")->chain($tPackets->getInputLabel());

	# the dump request processing
	$faIn->getLabel("dumprq")->makeChained("dump", undef, sub {
		if ($_[1]->getRow()->get("what") eq "packets") {
			$tPackets->dumpAll();
		}
	});

	$owner->readyReady();
	$owner->mainLoop(); # all driven by the reader
}

# Create all the other threads and then read the tail of the
# pipeline and print the data from it.
# Options inherited from Triead::start.
sub PrintMain # (@opts)
{
	my $opts = {};
	Triceps::Opt::parse("traffic main", $opts, {@Triceps::Triead::opts}, @_);
	my $owner = $opts->{owner};
	my $unit = $owner->unit();

	Triceps::Triead::start(
		app => $opts->{app},
		thread => "read",
		main => \&ReaderMain,
	);
	Triceps::Triead::start(
		app => $opts->{app},
		thread => "raw_hour",
		main => \&RawToHourlyMain,
		from => "read/data",
	);
if (0) {
	Triceps::Triead::start(
		app => $opts->{app},
		thread => "hour_day",
		main => \&HourlyToDailyMain,
		from => "raw_hour/data",
	);
	Triceps::Triead::start(
		app => $opts->{app},
		thread => "day",
		main => \&StoreDailyMain,
		from => "hour_day/data",
	);
}

	my $faIn = $owner->importNexus(
		from => "raw_hour/data",
		as => "input",
		import => "reader",
	);

	$faIn->getLabel("print")->makeChained("print", undef, sub {
		&send($_[1]->getRow()->get("text"));
	});
	for my $tag ("packet", "hourly", "dumpPackets") {
		makePrintLabel($tag, $faIn->getLabel($tag));
	}

	$owner->readyReady();
	$owner->mainLoop(); # all driven by the reader
}

sub RUN {

Triceps::Triead::startHere(
	app => "traffic",
	thread => "print",
	main => \&PrintMain,
);

};

package main;

setInputLines(
	"new,OP_INSERT,1330886011000000,1.2.3.4,5.6.7.8,2000,80,100\n",
	"new,OP_INSERT,1330886012000000,1.2.3.4,5.6.7.8,2000,80,50\n",
	"new,OP_INSERT,1330889811000000,1.2.3.4,5.6.7.8,2000,80,300\n",
	"new,OP_INSERT,1330972411000000,1.2.3.5,5.6.7.9,3000,80,200\n",
	"new,OP_INSERT,1331058811000000\n",
	"new,OP_INSERT,1331145211000000\n",
	"dump,packets\n",
);
&Traffic1::RUN();
#print &getResultLines();
ok(&getResultLines(), 
'> new,OP_INSERT,1330886011000000,1.2.3.4,5.6.7.8,2000,80,100
input.packet OP_INSERT time="1330886011000000" local_ip="1.2.3.4" remote_ip="5.6.7.8" local_port="2000" remote_port="80" bytes="100" 
input.hourly OP_INSERT time="1330884000000000" local_ip="1.2.3.4" remote_ip="5.6.7.8" bytes="100" 
> new,OP_INSERT,1330886012000000,1.2.3.4,5.6.7.8,2000,80,50
input.packet OP_INSERT time="1330886012000000" local_ip="1.2.3.4" remote_ip="5.6.7.8" local_port="2000" remote_port="80" bytes="50" 
input.hourly OP_DELETE time="1330884000000000" local_ip="1.2.3.4" remote_ip="5.6.7.8" bytes="100" 
input.hourly OP_INSERT time="1330884000000000" local_ip="1.2.3.4" remote_ip="5.6.7.8" bytes="150" 
> new,OP_INSERT,1330889811000000,1.2.3.4,5.6.7.8,2000,80,300
input.packet OP_INSERT time="1330889811000000" local_ip="1.2.3.4" remote_ip="5.6.7.8" local_port="2000" remote_port="80" bytes="300" 
input.hourly OP_INSERT time="1330887600000000" local_ip="1.2.3.4" remote_ip="5.6.7.8" bytes="300" 
> new,OP_INSERT,1330972411000000,1.2.3.5,5.6.7.9,3000,80,200
input.packet OP_INSERT time="1330972411000000" local_ip="1.2.3.5" remote_ip="5.6.7.9" local_port="3000" remote_port="80" bytes="200" 
input.hourly OP_INSERT time="1330970400000000" local_ip="1.2.3.5" remote_ip="5.6.7.9" bytes="200" 
> new,OP_INSERT,1331058811000000
input.packet OP_INSERT time="1331058811000000" 
input.hourly OP_INSERT time="1331056800000000" bytes="0" 
> new,OP_INSERT,1331145211000000
input.packet OP_INSERT time="1331145211000000" 
input.hourly OP_INSERT time="1331143200000000" bytes="0" 
> dump,packets
input.dumpPackets OP_INSERT time="1330886011000000" local_ip="1.2.3.4" remote_ip="5.6.7.8" local_port="2000" remote_port="80" bytes="100" 
input.dumpPackets OP_INSERT time="1330886012000000" local_ip="1.2.3.4" remote_ip="5.6.7.8" local_port="2000" remote_port="80" bytes="50" 
input.dumpPackets OP_INSERT time="1330889811000000" local_ip="1.2.3.4" remote_ip="5.6.7.8" local_port="2000" remote_port="80" bytes="300" 
input.dumpPackets OP_INSERT time="1330972411000000" local_ip="1.2.3.5" remote_ip="5.6.7.9" local_port="3000" remote_port="80" bytes="200" 
input.dumpPackets OP_INSERT time="1331058811000000" 
input.dumpPackets OP_INSERT time="1331145211000000" 
');
