//
// This file is a part of Triceps.
// See the file COPYRIGHT for the copyright notice and license information
//
// The wrapper for Table.

#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include "ppport.h"

#include "TricepsPerl.h"

namespace Triceps
{
namespace TricepsPerl 
{

// Parse the argument as either a RowHandle (then return it directly)
// or a Row (then create a RowHandle from it). On errors returns NULL
// and sets the message.
// @patab tab - table where the handle will be used
// @param funcName - calling function name, for error messages
// @param arg - the incoming argument
// @return - a RowHandle, or NULL on error; put it into Rhref because handle may be just created!!!
RowHandle *parseRowOrHandle(Table *tab, const char *funcName, SV *arg)
{
	if( sv_isobject(arg) && (SvTYPE(SvRV(arg)) == SVt_PVMG) ) {
		WrapRowHandle *wrh = (WrapRowHandle *)SvIV((SV*)SvRV( arg ));
		if (wrh == 0) {
			setErrMsg( string(funcName) + ": row argument is NULL and not a valid SV reference to Row or RowHandle" );
			return NULL;
		}
		if (!wrh->badMagic()) {
			if (wrh->ref_.getTable() != tab) {
				setErrMsg( strprintf("%s: row argument is a RowHandle in a wrong table %s",
					funcName, wrh->ref_.getTable()->getName().c_str()) );
				return NULL;
			}
			RowHandle *rh = wrh->get();
			if (rh == NULL) {
				setErrMsg( strprintf("%s: RowHandle is NULL", funcName) );
				return NULL;
			}
			return rh;
		}
		WrapRow *wr = (WrapRow *)wrh;
		if (wr->badMagic()) {
			setErrMsg( string(funcName) + ": row argument has an incorrect magic for Row or RowHandle" );
			return NULL;
		}

		Row *r = wr->get();
		RowType *rt = wr->ref_.getType();

		if (!rt->equals(tab->getRowType())) {
			string msg = strprintf("%s: table and row types are not equal, in table: ", funcName);
			tab->getRowType()->printTo(msg, NOINDENT);
			msg.append(", in row: ");
			rt->printTo(msg, NOINDENT);

			setErrMsg(msg);
			return NULL;
		}
		return tab->makeRowHandle(r);
	} else{
		setErrMsg( string(funcName) + ": row argument is not a blessed SV reference to Row or RowHandle" );
		return NULL;
	}
}

// Parse the copyTray argument for table ops.
Tray *parseCopyTray(Table *tab, const char *funcName, SV *arg)
{
	if( sv_isobject(arg) && (SvTYPE(SvRV(arg)) == SVt_PVMG) ) {
		WrapTray *wt = (WrapTray *)SvIV((SV*)SvRV( arg ));
		if (wt == 0 || wt->badMagic()) {
			setErrMsg( string(funcName) + ": copyTray has an incorrect magic for WrapTray" );
			return NULL;
		}
		if (wt->getParent() != tab->getUnit()) {
			setErrMsg( strprintf("%s: copyTray is from a wrong unit %s, table in unit %s", funcName,
				wt->getParent()->getName().c_str(), tab->getUnit()->getName().c_str()) );
			return NULL;
		}
		return wt->get();
	} else{
		setErrMsg( string(funcName) + ": copyTray is not a blessed SV reference to WrapTray" );
		return NULL;
	}
}

}; // Triceps::TricepsPerl
}; // Triceps

MODULE = Triceps::Table		PACKAGE = Triceps::Table
###################################################################################

void
DESTROY(WrapTable *self)
	CODE:
		// warn("Table destroyed!");
		delete self;


# The table gets created by Unit::makeTable

WrapLabel *
getInputLabel(WrapTable *self)
	CODE:
		// for casting of return value
		static char CLASS[] = "Triceps::Label";

		clearErrMsg();
		Table *t = self->get();
		RETVAL = new WrapLabel(t->getInputLabel());
	OUTPUT:
		RETVAL

# since the C++ inheritance doesn't propagate to Perl, the inherited call getLabel()
# becomes an explicit getOutputLabel()
WrapLabel *
getOutputLabel(WrapTable *self)
	CODE:
		// for casting of return value
		static char CLASS[] = "Triceps::Label";

		clearErrMsg();
		Table *t = self->get();
		RETVAL = new WrapLabel(t->getLabel());
	OUTPUT:
		RETVAL

WrapTableType *
getType(WrapTable *self)
	CODE:
		// for casting of return value
		static char CLASS[] = "Triceps::TableType";

		clearErrMsg();
		Table *t = self->get();
		RETVAL = new WrapTableType(const_cast<TableType *>(t->getType()));
	OUTPUT:
		RETVAL

WrapUnit*
getUnit(WrapTable *self)
	CODE:
		clearErrMsg();
		Table *tab = self->get();

		// for casting of return value
		static char CLASS[] = "Triceps::Unit";
		RETVAL = new WrapUnit(tab->getUnit());
	OUTPUT:
		RETVAL

# check whether both refs point to the same type object
int
same(WrapTable *self, WrapTable *other)
	CODE:
		clearErrMsg();
		Table *t = self->get();
		Table *ot = other->get();
		RETVAL = (t == ot);
	OUTPUT:
		RETVAL

WrapRowType *
getRowType(WrapTable *self)
	CODE:
		clearErrMsg();
		Table *tab = self->get();

		// for casting of return value
		static char CLASS[] = "Triceps::RowType";
		RETVAL = new WrapRowType(const_cast<RowType *>(tab->getRowType()));
	OUTPUT:
		RETVAL

char *
getName(WrapTable *self)
	CODE:
		clearErrMsg();
		Table *t = self->get();
		RETVAL = (char *)t->getName().c_str();
	OUTPUT:
		RETVAL

# this may be 64-bit, and IV is guaranteed to be pointer-sized
IV
size(WrapTable *self)
	CODE:
		clearErrMsg();
		Table *t = self->get();
		RETVAL = t->size();
	OUTPUT:
		RETVAL

WrapRowHandle *
makeRowHandle(WrapTable *self, WrapRow *row)
	CODE:
		static char funcName[] =  "Triceps::Table::makeRowHandle";
		// for casting of return value
		static char CLASS[] = "Triceps::RowHandle";

		clearErrMsg();
		Table *t = self->get();
		Row *r = row->get();
		RowType *rt = row->ref_.getType();

		if (!rt->equals(t->getRowType())) {
			string msg = strprintf("%s: table and row types are not equal, in table: ", funcName);
			t->getRowType()->printTo(msg, NOINDENT);
			msg.append(", in row: ");
			rt->printTo(msg, NOINDENT);

			setErrMsg(msg);
			XSRETURN_UNDEF;
		}

		RETVAL = new WrapRowHandle(t, t->makeRowHandle(r));
	OUTPUT:
		RETVAL

# I'm not sure if there is much use for it, but just in case...
WrapRowHandle *
makeNullRowHandle(WrapTable *self)
	CODE:
		// for casting of return value
		static char CLASS[] = "Triceps::RowHandle";

		clearErrMsg();
		Table *t = self->get();

		RETVAL = new WrapRowHandle(t, NULL);
	OUTPUT:
		RETVAL


# returns: 1 on success, 0 if the policy didn't allow the insert, undef on an error
int
insert(WrapTable *self, SV *rowarg, ...)
	CODE:
		static char funcName[] =  "Triceps::Table::insert";
		if (items != 2 && items != 3)
		   Perl_croak(aTHX_ "Usage: %s(self, rowarg [, copyTray])", funcName);

		clearErrMsg();
		Table *t = self->get();

		Rhref rhr(t,  parseRowOrHandle(t, funcName, rowarg));
		if (rhr.isNull())
			XSRETURN_UNDEF;

		Tray *ctr = NULL;
		if (items == 3) {
			ctr = parseCopyTray(t, funcName, ST(2));
			if (ctr ==  NULL)
				XSRETURN_UNDEF;
		}

		RETVAL = t->insert(rhr.get(), ctr);
	OUTPUT:
		RETVAL

# returns 1 normally, or undef on incorrect arguments
# XXX add a version that takes a Row as an argument and does find/remove?
int
remove(WrapTable *self, WrapRowHandle *wrh, ...)
	CODE:
		static char funcName[] =  "Triceps::Table::remove";
		if (items != 2 && items != 3)
		   Perl_croak(aTHX_ "Usage: %s(self, rowHandle [, copyTray])", funcName);

		clearErrMsg();
		Table *t = self->get();
		RowHandle *rh = wrh->get();

		if (rh == NULL) {
			setErrMsg( strprintf("%s: RowHandle is NULL", funcName) );
			XSRETURN_UNDEF;
		}

		if (wrh->ref_.getTable() != t) {
			setErrMsg( strprintf("%s: row argument is a RowHandle in a wrong table %s",
				funcName, wrh->ref_.getTable()->getName().c_str()) );
			XSRETURN_UNDEF;
		}

		Tray *ctr = NULL;
		if (items == 3) {
			ctr = parseCopyTray(t, funcName, ST(2));
			if (ctr ==  NULL)
				XSRETURN_UNDEF;
		}

		t->remove(rh, ctr);
		RETVAL = 1;
	OUTPUT:
		RETVAL

# RowHandle with NULL pointer in it is used for the end-iterator

WrapRowHandle *
begin(WrapTable *self)
	CODE:
		static char CLASS[] = "Triceps::RowHandle";

		clearErrMsg();
		Table *t = self->get();
		RETVAL = new WrapRowHandle(t, t->begin());
	OUTPUT:
		RETVAL
		
WrapRowHandle *
beginIdx(WrapTable *self, WrapIndexType *widx)
	CODE:
		static char CLASS[] = "Triceps::RowHandle";

		clearErrMsg();
		Table *t = self->get();
		IndexType *idx = widx->get();

		static char funcName[] =  "Triceps::Table::beginIdx";
		if (idx->getTabtype() != t->getType()) {
			setErrMsg( strprintf("%s: indexType argument does not belong to table's type", funcName) );
			XSRETURN_UNDEF;
		}

		RETVAL = new WrapRowHandle(t, t->beginIdx(idx));
	OUTPUT:
		RETVAL

WrapRowHandle *
next(WrapTable *self, WrapRowHandle *wcur)
	CODE:
		static char CLASS[] = "Triceps::RowHandle";

		clearErrMsg();
		Table *t = self->get();
		RowHandle *cur = wcur->get(); // NULL is OK

		static char funcName[] =  "Triceps::Table::next";
		if (wcur->ref_.getTable() != t) {
			setErrMsg( strprintf("%s: row argument is a RowHandle in a wrong table %s",
				funcName, wcur->ref_.getTable()->getName().c_str()) );
			XSRETURN_UNDEF;
		}

		RETVAL = new WrapRowHandle(t, t->next(cur));
	OUTPUT:
		RETVAL
		
WrapRowHandle *
nextIdx(WrapTable *self, WrapIndexType *widx, WrapRowHandle *wcur)
	CODE:
		static char CLASS[] = "Triceps::RowHandle";

		clearErrMsg();
		Table *t = self->get();
		IndexType *idx = widx->get();
		RowHandle *cur = wcur->get(); // NULL is OK

		static char funcName[] =  "Triceps::Table::nextIdx";
		if (idx->getTabtype() != t->getType()) {
			setErrMsg( strprintf("%s: indexType argument does not belong to table's type", funcName) );
			XSRETURN_UNDEF;
		}
		if (wcur->ref_.getTable() != t) {
			setErrMsg( strprintf("%s: row argument is a RowHandle in a wrong table %s",
				funcName, wcur->ref_.getTable()->getName().c_str()) );
			XSRETURN_UNDEF;
		}

		RETVAL = new WrapRowHandle(t, t->nextIdx(idx, cur));
	OUTPUT:
		RETVAL
		
WrapRowHandle *
firstOfGroupIdx(WrapTable *self, WrapIndexType *widx, WrapRowHandle *wcur)
	CODE:
		static char CLASS[] = "Triceps::RowHandle";

		clearErrMsg();
		Table *t = self->get();
		IndexType *idx = widx->get();
		RowHandle *cur = wcur->get(); // NULL is OK

		static char funcName[] =  "Triceps::Table::firstOfGroupIdx";
		if (idx->getTabtype() != t->getType()) {
			setErrMsg( strprintf("%s: indexType argument does not belong to table's type", funcName) );
			XSRETURN_UNDEF;
		}
		if (wcur->ref_.getTable() != t) {
			setErrMsg( strprintf("%s: row argument is a RowHandle in a wrong table %s",
				funcName, wcur->ref_.getTable()->getName().c_str()) );
			XSRETURN_UNDEF;
		}

		RETVAL = new WrapRowHandle(t, t->firstOfGroupIdx(idx, cur));
	OUTPUT:
		RETVAL
		
WrapRowHandle *
nextGroupIdx(WrapTable *self, WrapIndexType *widx, WrapRowHandle *wcur)
	CODE:
		static char CLASS[] = "Triceps::RowHandle";

		clearErrMsg();
		Table *t = self->get();
		IndexType *idx = widx->get();
		RowHandle *cur = wcur->get(); // NULL is OK

		static char funcName[] =  "Triceps::Table::nextGroupIdx";
		if (idx->getTabtype() != t->getType()) {
			setErrMsg( strprintf("%s: indexType argument does not belong to table's type", funcName) );
			XSRETURN_UNDEF;
		}
		if (wcur->ref_.getTable() != t) {
			setErrMsg( strprintf("%s: row argument is a RowHandle in a wrong table %s",
				funcName, wcur->ref_.getTable()->getName().c_str()) );
			XSRETURN_UNDEF;
		}

		RETVAL = new WrapRowHandle(t, t->nextGroupIdx(idx, cur));
	OUTPUT:
		RETVAL
		
WrapRowHandle *
find(WrapTable *self, SV *rowarg)
	CODE:
		static char CLASS[] = "Triceps::RowHandle";
		static char funcName[] =  "Triceps::Table::find";
		if (items != 2 && items != 3)
		   Perl_croak(aTHX_ "Usage: %s(self, rowarg)", funcName);

		clearErrMsg();
		Table *t = self->get();

		Rhref rhr(t,  parseRowOrHandle(t, funcName, rowarg));
		if (rhr.isNull())
			XSRETURN_UNDEF;

		RETVAL = new WrapRowHandle(t, t->find(rhr.get()));
	OUTPUT:
		RETVAL

WrapRowHandle *
findIdx(WrapTable *self, WrapIndexType *widx, SV *rowarg)
	CODE:
		static char CLASS[] = "Triceps::RowHandle";
		static char funcName[] =  "Triceps::Table::findIdx";
		if (items != 2 && items != 3)
		   Perl_croak(aTHX_ "Usage: %s(self, rowarg)", funcName);

		clearErrMsg();
		Table *t = self->get();
		IndexType *idx = widx->get();

		if (idx->getTabtype() != t->getType()) {
			setErrMsg( strprintf("%s: indexType argument does not belong to table's type", funcName) );
			XSRETURN_UNDEF;
		}

		Rhref rhr(t,  parseRowOrHandle(t, funcName, rowarg));
		if (rhr.isNull())
			XSRETURN_UNDEF;

		RETVAL = new WrapRowHandle(t, t->findIdx(idx, rhr.get()));
	OUTPUT:
		RETVAL

