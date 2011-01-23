//
// This file is a part of Biceps.
// See the file COPYRIGHT for the copyright notice and license information
//
//
// The common buffer base of all the row implementations.

#include <mem/MtBuffer.h>
#include <stdlib.h>
#include <stdio.h>

namespace BICEPS_NS {

/////////////////////// MtBuffer ////////////////////////

void *MtBuffer::operator new(size_t basic, intptr_t variable)
{
	return malloc((intptr_t)basic + variable);
}

void MtBuffer::operator delete(void *ptr)
{
	free(ptr);
}

/////////////////////// VirtualMtBuffer ////////////////////////

void *VirtualMtBuffer::operator new(size_t basic, intptr_t variable)
{
	return malloc((intptr_t)basic + variable);
}

void VirtualMtBuffer::operator delete(void *ptr)
{
	free(ptr);
}

VirtualMtBuffer::~VirtualMtBuffer()
{ }

}; // BICEPS_NS
