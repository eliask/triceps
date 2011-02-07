//
// This file is a part of Biceps.
// See the file COPYRIGHT for the copyright notice and license information
//
//
// A reference-counted byte buffer

#ifndef __Biceps_RowHandle_h__
#define __Biceps_RowHandle_h__

#include <common/Common.h>
#include <mem/Starget.h>
#include <mem/Row.h>

namespace BICEPS_NS {

class Table;

// The RowHandles are owned by the Table, and as such must be accessed
// from one thread only. This allows to use the cheaper Starget base.
class RowHandle : public Starget
{
public:
	// flags describing the state of handle
	enum Flags {
		F_INTABLE = 0x01, // the handle is currently stored in the table and can be used as an interator in it
	};

	// the longest type used for the alignment 
	typedef double AlignType;

	// Allocation initializes the memory to 0.
	// @param basic - provided by C++ compiler, size of the basic structure
	// @param variable - actual size in bytes for data_[]
	static void *operator new(size_t basic, intptr_t variable)
	{
		return calloc(1, (intptr_t)basic + variable - sizeof(data_)); 
	}
	static void operator delete(void *ptr)
	{
		free(ptr);
	}

	// here offsets are relative to &data_!
	char *at(intptr_t offset) const
	{
		return ((char *)&data_) + offset;
	}

	// With casting, for convenience
	template <typename T>
	T *get(intptr_t offset) const
	{
		return (T *)at(offset);
	}

	const Row *getRow() const
	{
		return row_;
	}

	bool isInTable() const
	{
		return (flags_ & F_INTABLE);
	}

protected:
	friend class Table;
	friend class RowHandleType;

	RowHandle(const Row *row) : // Table knows to incref() the row before this
		flags_(0),
		row_(row)
	{ }
	
	~RowHandle() // only Table knows how to destroy the contents properly
	{ }

protected:
	int32_t flags_; // together with Starget ref counter, this should result in 64-bit alignment
	const Row *row_; // the row owned by this handle
	AlignType data_; // used to focre the initial alignment
};

}; // BICEPS_NS

#endif // __Biceps_RowHandle_h__
