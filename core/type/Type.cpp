//
// This file is a part of Biceps.
// See the file COPYRIGHT for the copyright notice and license information
//

#include <type/AllSimpleTypes.h>

namespace Biceps {

Autoref<const SimpleType> Type::r_void(new VoidType);
Autoref<const SimpleType> Type::r_uint8(new Uint8Type);
Autoref<const SimpleType> Type::r_int32(new Int32Type);
Autoref<const SimpleType> Type::r_int64(new Int64Type);
Autoref<const SimpleType> Type::r_float64(new Float64Type);
Autoref<const SimpleType> Type::r_string(new StringType);

}; // Biceps
