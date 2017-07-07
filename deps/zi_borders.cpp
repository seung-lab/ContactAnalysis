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


template< typename T >
inline T most_common( const T& a1, const T& a2, const T& a3, const T& a4,
                      const T& a5, const T& a6 )
{
    std::map<T,int> total;
    ++total[a1];
    ++total[a2];
    ++total[a3];
    ++total[a4];
    ++total[a5];
    ++total[a6];

    int max = 0;
    T   r = a1;

    for ( typename std::map<T,int>::const_iterator it = total.begin(); it != total.end(); ++it )
    {
        if ( it->first && (it->second > max) )
        {
            r = it->first;
            max = it->second;
        }

    }

    return r;
}

template< typename T >
inline void expand( std::size_t xs, std::size_t ys, std::size_t zs, T* ids )
{
    std::size_t total = xs*ys*zs;

    int* tmp2 = new int[total];
    std::fill_n( tmp2, total, 0 );

    const std::size_t dx = 1;
    const std::size_t dy = xs;
    const std::size_t dz = xs*ys;

    for ( std::size_t oidx = 0, k = 0; k < zs; ++k )
        for ( std::size_t j = 0; j < ys; ++j )
            for ( std::size_t i = 0; i < xs; ++i, ++oidx )
            {
                if ( ids[oidx] == 0 )
                {
                    int isxp =
                        ( i > 0 ? tmp2[oidx-dx] : 0 ) +
                        ( j > 0 ? tmp2[oidx-dy] : 0 ) +
                        ( k > 0 ? tmp2[oidx-dz] : 0 ) +
                        ( i < xs - 1 ? tmp2[oidx+dx] : 0 ) +
                        ( j < ys - 1 ? tmp2[oidx+dy] : 0 ) +
                        ( k < zs - 1 ? tmp2[oidx+dz] : 0 );

                    if ( isxp == 0 )
                    {
                        ids[oidx] = most_common<T>(
                            ( i > 0 ? ids[oidx-dx] : 0 ),
                            ( j > 0 ? ids[oidx-dy] : 0 ),
                            ( k > 0 ? ids[oidx-dz] : 0 ),
                            ( i < xs - 1 ? ids[oidx+dx] : 0 ),
                            ( j < ys - 1 ? ids[oidx+dy] : 0 ),
                            ( k < zs - 1 ? ids[oidx+dz] : 0 ) );

                        if ( ids[oidx] )
                            tmp2[oidx] = 1;
                    }
                }
            }

    delete [] tmp2;
}


template< typename T >
inline void append( const T& a, const T& b, std::map<std::pair<T,T>, int>& ret )
{
    if ( a && b && ( a != b ) )
    {
        ++ret[std::pair<T,T>(a,b)];
    }
}

template< typename T >
inline void count_touches( std::size_t xs,
                           std::size_t ys,
                           std::size_t zs,
                           T*    ids,
                           std::map<std::pair<T,T>, int>& ret,
                           std::size_t to_expand = 0 )
{
    while ( to_expand-- )
    {
        expand(xs, ys, zs, ids);
    }

    ret.clear();

    const std::size_t dx = 1;
    const std::size_t dy = xs;
    const std::size_t dz = xs*ys;

    for ( std::size_t oidx = 0, k = 0; k < zs; ++k )
        for ( std::size_t j = 0; j < ys; ++j )
            for ( std::size_t i = 0; i < xs; ++i, ++oidx )
            {
                if ( i > 0 ) append(ids[oidx],ids[oidx-dx],ret);
                if ( j > 0 ) append(ids[oidx],ids[oidx-dy],ret);
                if ( k > 0 ) append(ids[oidx],ids[oidx-dz],ret);
            }
}

#include "mex.h"

void mexFunction(int nlhs, mxArray* plhs[], int nrhs, const mxArray* prhs[])
{
    if ( nrhs != 1 && nrhs != 2 )
    {
        mexErrMsgTxt("Not enough arguments");
    }

    const mwSize num_dim = mxGetNumberOfDimensions(prhs[0]);

    if ( num_dim != 3 )
    {
        mexErrMsgTxt("Wrong number of dimensions of the first argument");
    }

    const mwSize* dims = mxGetDimensions(prhs[0]);

    std::size_t to_expand = 0;

    if ( nrhs == 2 )
    {
        to_expand = static_cast<std::size_t>(mxGetScalar(prhs[1]));
    }

    std::size_t total = dims[0]*dims[1]*dims[2];

    if ( nlhs == 0 )
    {
        //mexErrMsgTxt("Need output variable");
    }

    int* tmp = new int[total];
    std::copy( reinterpret_cast<int*>(mxGetData(prhs[0])),
               reinterpret_cast<int*>(mxGetData(prhs[0])) + total,
               tmp );


    std::map<std::pair<int,int>,int> r;

    count_touches<int>( dims[0], dims[1], dims[2], tmp, r, to_expand );


    for ( std::map<std::pair<int,int>,int>::const_iterator it = r.begin(); it != r.end(); ++it )
    {
        //std::cout << it->first.first << ' ' << it->first.second << " : " << it->second << "\n";
    }

    mwSize out_dim[] = { 3, r.size() };
    mwSize out_dims  = 2;

    plhs[0] = mxCreateNumericArray( out_dims, out_dim,
                                    mxINT32_CLASS,
                                    mxREAL );

    int* spit = reinterpret_cast<int*>(mxGetData(plhs[0]));
    std::size_t idx = 0;

    for ( std::map<std::pair<int,int>,int>::const_iterator it = r.begin(); it != r.end(); ++it )
    {
        if ( it->first.first == it->first.second )
        {
            std::cout << it->first.first << ' ' << it->first.second << " : " << it->second << "\n";
        }
        spit[idx++] = it->first.first;
        spit[idx++] = it->first.second;
        spit[idx++] = it->second;
    }


    delete [] tmp;

}
