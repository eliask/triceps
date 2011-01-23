//
// This file is a part of Biceps.
// See the file COPYRIGHT for the copyright notice and license information
//
//
// A common way for reporting of the errors

#ifndef __Biceps_Errors_h__
#define __Biceps_Errors_h__

#include <vector>
#include <string>
#include <mem/Starget.h>

namespace BICEPS_NS {

using namespace std;

// Each function that does the check for the correctness of data supplied
// by the user must return the detailed messages about these errors.
// The checking doesn't have to stop on the first error, it may continue
// to find as many errors in one go as possible.
// As the error detection unwinds, it has to preserve the hierarachy of
// messages returned.
class Errors: public Starget, public vector <string>
{
public:
	// Since the error checking normally happens in one thread,
	// using the Stragtet should be fine.
	//
	// The messages from this element are collected in the parent vector,
	// and inheriting it allows to skip doing the wrappers for all its methods.
	//
	// This same structure can be used to report warnings too, so the flag
	// error_ shows that there actually was an error.
	
	// The default of false allows to collect the child errors by append(),
	// which would set it to true if any child found an error, and of course
	// the erro flag can be set directly in this object too.
	Errors(bool e = false);

	// A convenience function to add the child's info.
	// If the child had the erro flag set, sets the error flag here too.
	// @param child - errors returned by child (or NULL)
	// @return - true if the child returned and error
	bool append(Autoref<Errors> clde);

	// Append a direct error message.
	// @param e - flag: true if error, false if warning
	// @param msg - the error message
	void appendMsg(bool e, const string &msg);

	// Check recursively whether ethere are no messages.
	// @return - true if there are no messages throughout hierarchy
	bool isEmpty();

	// Check if has an error.
	// @return - true if has an error
	bool hasError()
	{
		return error_;
	}
	
	// Print the messages recursively by appending them to a string.
	// @param res - the resulting string to append to
	// @param indent - initial indentation characters
	// @param subindent - indentation characters to add on each level
	void printTo(string &res, const string &indent = "", const string &subindent = "  ");

	// Print in a simple way and return the result string.
	// @param indent - initial indentation characters
	// @param subindent - indentation characters to add on each level
	// @return - the result string
	string print(const string &indent = "", const string &subindent = "  ");

public:
	bool error_; // true if there is an error somewhere, false if only warnings
	Autoref<Errors> cfirst_; // first child
	Autoref<Errors> clast_; // last child, for addition
	Autoref<Errors> sibling_; // next sibling, allows to build a tree
	// In the future, may also have the strucutred information about the location of error
};

// the typical error indication returned by the parsing functions
typedef Autoref<Errors> Erref;

}; // BICEPS_NS

#endif // __Biceps_Errors_h__
