function [ R ] = count_touches_hdf5( seg, width, exp )

[ ign s ] = get_hdf5_size( seg, '/main' );

R = zeros(3,0,'int32');

xind = 0;
for x = 1:width:s( 1 ),
    yind = 0;
    for y = 1:width:s( 2 ),
        zind = 0;
        for z = 1:width:s( 3 ),
            cto   = min( [ x y z ] + width, s( 1:3 ) );
            cfrom = max( [ 1 1 1 ], [ x y z ] - 1 );

            part = get_hdf5_file( seg, '/main', cfrom, cto );

            R = [R zi_borders( part, exp ) ];

            zind = zind + 1;

            fprintf( 'done with %d:%d:%d size: [ %d %d %d ]\n', ...
                      x, y, z, cto - cfrom + 1 );

        end;
        yind = yind + 1;
    end;
    xind = xind + 1;
end

R = zi_merge(R);