// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions
// are met:
//  * Redistributions of source code must retain the above copyright
//    notice, this list of conditions and the following disclaimer.
//  * Redistributions in binary form must reproduce the above copyright
//    notice, this list of conditions and the following disclaimer in the
//    documentation and/or other materials provided with the distribution.
//  * Neither the name of NVIDIA CORPORATION nor the names of its
//    contributors may be used to endorse or promote products derived
//    from this software without specific prior written permission.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS ''AS IS'' AND ANY
// EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
// IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
// PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL THE COPYRIGHT OWNER OR
// CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
// EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
// PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
// PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY
// OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
// (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
// OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//
// Copyright (c) 2008-2024 NVIDIA Corporation. All rights reserved.
// Copyright (c) 2004-2008 AGEIA Technologies, Inc. All rights reserved.
// Copyright (c) 2001-2004 NovodeX AG. All rights reserved.

#ifndef PXFOUNDATION_PXUNIXFPU_H
#define PXFOUNDATION_PXUNIXFPU_H

#include "foundation/PxPreprocessor.h"

#if PX_LINUX || PX_OSX

#if PX_X86 || PX_X64
#if PX_EMSCRIPTEN
#include <emmintrin.h>
#endif
#include <xmmintrin.h>
#elif PX_NEON
#include <arm_neon.h>
#endif

PX_INLINE physx::PxSIMDGuard::PxSIMDGuard(bool enable) 
#if !PX_EMSCRIPTEN && (PX_X86 || PX_X64)
	: mEnabled(enable)
#endif
{
#if !PX_EMSCRIPTEN && (PX_X86 || PX_X64)
	if(enable)
	{
		mControlWord = _mm_getcsr();
		// set default (disable exceptions: _MM_MASK_MASK) and FTZ (_MM_FLUSH_ZERO_ON), DAZ (_MM_DENORMALS_ZERO_ON: (1<<6))
		_mm_setcsr(_MM_MASK_MASK | _MM_FLUSH_ZERO_ON | (1 << 6));
	}
	else
	{
		PX_UNUSED(enable);
		PX_ASSERT(_mm_getcsr() & _MM_FLUSH_ZERO_ON);
		PX_ASSERT(_mm_getcsr() & (1 << 6));
		PX_ASSERT(_mm_getcsr() & _MM_MASK_MASK);
	}
#endif
}

PX_INLINE physx::PxSIMDGuard::~PxSIMDGuard()
{
#if !PX_EMSCRIPTEN && (PX_X86 || PX_X64)
	if(mEnabled)
	{
		// restore control word and clear exception flags
		// (setting exception state flags cause exceptions on the first following fp operation)
		_mm_setcsr(mControlWord & PxU32(~_MM_EXCEPT_MASK));
	}
#endif
}

#else
	#error No SIMD implementation for this unix platform.
#endif // PX_LINUX || PX_OSX

#endif // #ifndef PXFOUNDATION_PXUNIXFPU_H
