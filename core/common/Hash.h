//
// This file is a part of Biceps.
// See the file COPYRIGHT for the copyright notice and license information
//
//
// Hash functions calculation.

#ifndef __Biceps_Hash_h__
#define __Biceps_Hash_h__

#include <common/Common.h>

namespace BICEPS_NS {

class Hash
{
public:
	// This uses FNV-1a algorithm, as decribed in http://isthe.com/chongo/tech/comp/fnv/

#if 1
	// 32-bit hash, should be enough
	typedef uint32_t Value;
	typedef int32_t SValue; // signed version

	static const Value basis_ = 2166136261; // to initialize before calculating the hash
	static const Value prime_ = 16777619; // for multiplication
#else
	// 64-bit constants, just in case
	typedef uint64_t Value;
	typedef int64_t SValue; // signed version

	static const Value basis_ = 14695981039346656037; // to initialize before calculating the hash
	static const Value prime_ = 1099511628211; // for multiplication
#endif

	// Append one byte to the hash value.
	// @param prev - previous hash value
	// @param byte - byte to append
	// @return - the new hash value
	Value addByte(Value prev, unsigned char b)
	{
		return (prev ^ b) * prime_;
	}

	// Append one byte to the hash value.
	// @param prev - previous hash value
	// @param byte - byte to append
	// @return - the new hash value
	Value append(Value prev, const char *v, size_t len)
	{
		const char *end = v + len;
		while (v != end) {
			prev = (prev ^ *(const unsigned char*)(v++)) * prime_;
		}
		return prev;
	}
};

}; // BICEPS_NS

#endif // __Biceps_Hash_h__
