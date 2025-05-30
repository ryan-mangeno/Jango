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

#ifndef PX_PARTICLESYSTEM_GEOMETRY_H
#define PX_PARTICLESYSTEM_GEOMETRY_H
#include "geometry/PxGeometry.h"
#include "common/PxCoreUtilityTypes.h"
#include "foundation/PxBounds3.h"
#include "foundation/PxVec4.h"
#include "PxParticleSystem.h"
#include "PxParticleSolverType.h"

#if !PX_DOXYGEN
namespace physx
{
#endif

	/**
	\brief Particle system geometry class.

	*/
	class PxParticleSystemGeometry : public PxGeometry
	{
	public:
		/**
		\brief Default constructor.

		Creates an empty object with no particles.
		*/
		PX_INLINE PxParticleSystemGeometry() : PxGeometry(PxGeometryType::ePARTICLESYSTEM){}

		/**
		\brief Copy constructor.

		\param[in] that		Other object
		*/
		PX_INLINE PxParticleSystemGeometry(const PxParticleSystemGeometry& that) : PxGeometry(that) {}

		/**
		\brief Assignment operator
		*/
		PX_INLINE void operator=(const PxParticleSystemGeometry& that)
		{
			mType = that.mType;
			mSolverType = that.mSolverType;
		}

		/**
		\brief Returns true if the geometry is valid.

		\return  True if the current settings are valid for shape creation.

		\see PxRigidActor::createShape, PxPhysics::createShape
		*/
		PX_FORCE_INLINE bool isValid() const
		{
			if(mType != PxGeometryType::ePARTICLESYSTEM)
				return false;

			return true;
		}

		PX_DEPRECATED PxParticleSolverType::Enum mSolverType;
	};

#if !PX_DOXYGEN
} // namespace physx
#endif

#endif
