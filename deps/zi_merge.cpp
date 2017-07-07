//
// Copyright (C) 2013  Aleksandar Zlateski <zlateski@mit.edu>
// ----------------------------------------------------------
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.
//

#include <cstddef>
#include <cassert>
#include <cstring>
#include <cstdlib>
#include <iostream>
#include <utility>
#include <algorithm>
#include <map>
#include <stdint.h>
#include <vector>


#include "mex.h"

void mexFunction(int nlhs, mxArray* plhs[], int nrhs, const mxArray* prhs[])
{
    if ( nrhs != 1)
    {
        mexErrMsgTxt("Not enough arguments");
    }

    const mwSize num_dim = mxGetNumberOfDimensions(prhs[0]);

    if ( num_dim != 2 )
    {
        mexErrMsgTxt("Wrong number of dimensions of the first argument");
    }

    const mwSize* dims = mxGetDimensions(prhs[0]);

    if ( dims[0] != 3 )
    {
        mexErrMsgTxt("dims[0] has to be 3");
    }

    int* data = reinterpret_cast<int*>(mxGetData(prhs[0]));

    std::size_t idx = 0;

    std::map<std::pair<int,int>,int> r;

    for ( mwSize i = 0; i < dims[0]; ++i )
    {
        int a = data[idx++];
        int b = data[idx++];
        int c = data[idx++];

        r[std::pair<int,int>(std::min(a,b),std::max(a,b))] += c;
    }


    mwSize out_dim[] = { 3, r.size() };
    mwSize out_dims  = 2;

    plhs[0] = mxCreateNumericArray( out_dims, out_dim,
                                    mxINT32_CLASS,
                                    mxREAL );

    int* spit = reinterpret_cast<int*>(mxGetData(plhs[0]));
    idx = 0;

    for ( std::map<std::pair<int,int>,int>::const_iterator it = r.begin(); it != r.end(); ++it )
    {
        spit[idx++] = it->first.first;
        spit[idx++] = it->first.second;
        spit[idx++] = it->second;
    }

}
