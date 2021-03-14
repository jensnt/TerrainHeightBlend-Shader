// The MIT License (MIT) (see LICENSE.txt)
// Copyright © 2015 Inigo Quilez
// Copyright © 2021 Jens Neitzel

// One simple way to avoid texture tile repetition, at the cost of 4 times the amount of
// texture lookups (still much better than https://www.shadertoy.com/view/4tsGzf)
//
// More info: http://www.iquilezles.org/www/articles/texturerepetition/texturerepetition.htm

struct NoTileUVs
{
    fixed4 ofa, ofb, ofc, ofd;
    fixed2 uva, uvb, uvc, uvd, b;
    fixed2 ddxa, ddxb, ddxc, ddxd;
    fixed2 ddya, ddyb, ddyc, ddyd;
};

fixed4 hash4( fixed2 p ) { return frac(sin(fixed4( 1.0+dot(p,fixed2(37.0,17.0)),
                                                   2.0+dot(p,fixed2(11.0,47.0)),
                                                   3.0+dot(p,fixed2(41.0,29.0)),
                                                   4.0+dot(p,fixed2(23.0,31.0))))*103.0); }

NoTileUVs textureNoTileCalcUVs( in fixed2 uv )
{
    NoTileUVs ntuvs;
    fixed2 iuv = floor( uv );
    fixed2 fuv = frac( uv );

    // generate per-tile transform
    ntuvs.ofa = hash4( iuv + fixed2(0,0) );
    ntuvs.ofb = hash4( iuv + fixed2(1,0) );
    ntuvs.ofc = hash4( iuv + fixed2(0,1) );
    ntuvs.ofd = hash4( iuv + fixed2(1,1) );

    fixed2 uvddx = ddx( uv );
    fixed2 uvddy = ddy( uv );

    // transform per-tile uvs
    ntuvs.ofa.zw = sign(ntuvs.ofa.zw-0.5);
    ntuvs.ofb.zw = sign(ntuvs.ofb.zw-0.5);
    ntuvs.ofc.zw = sign(ntuvs.ofc.zw-0.5);
    ntuvs.ofd.zw = sign(ntuvs.ofd.zw-0.5);

    // uv's, and derivatives (for correct mipmapping)
    ntuvs.uva = uv*ntuvs.ofa.zw + ntuvs.ofa.xy; ntuvs.ddxa = uvddx*ntuvs.ofa.zw; ntuvs.ddya = uvddy*ntuvs.ofa.zw;
    ntuvs.uvb = uv*ntuvs.ofb.zw + ntuvs.ofb.xy; ntuvs.ddxb = uvddx*ntuvs.ofb.zw; ntuvs.ddyb = uvddy*ntuvs.ofb.zw;
    ntuvs.uvc = uv*ntuvs.ofc.zw + ntuvs.ofc.xy; ntuvs.ddxc = uvddx*ntuvs.ofc.zw; ntuvs.ddyc = uvddy*ntuvs.ofc.zw;
    ntuvs.uvd = uv*ntuvs.ofd.zw + ntuvs.ofd.xy; ntuvs.ddxd = uvddx*ntuvs.ofd.zw; ntuvs.ddyd = uvddy*ntuvs.ofd.zw;

    // fetch and blend
    ntuvs.b = smoothstep(0.25, 0.75, fuv);

    return ntuvs;
}

fixed4 textureNoTile( sampler2D samp, in NoTileUVs ntuvs )
{
    // Use modified UVs to sample a texture
    return lerp( lerp( tex2D( samp, ntuvs.uva, ntuvs.ddxa, ntuvs.ddya ),
                       tex2D( samp, ntuvs.uvb, ntuvs.ddxb, ntuvs.ddyb ), ntuvs.b.x ),
                 lerp( tex2D( samp, ntuvs.uvc, ntuvs.ddxc, ntuvs.ddyc ),
                       tex2D( samp, ntuvs.uvd, ntuvs.ddxd, ntuvs.ddyd ), ntuvs.b.x ), ntuvs.b.y );
}

fixed3 textureNoTileNormal( sampler2D sampNorm, in NoTileUVs ntuvs, in half normalScale )
{
    // Use modified UVs to sample a normal map, also inverting red and green channels where needed due to mirroring
    return lerp( lerp( fixed3( ntuvs.ofa.z, ntuvs.ofa.w, 1 ) * UnpackNormalWithScale( tex2D( sampNorm, ntuvs.uva, ntuvs.ddxa, ntuvs.ddya ), normalScale ),
                       fixed3( ntuvs.ofb.z, ntuvs.ofb.w, 1 ) * UnpackNormalWithScale( tex2D( sampNorm, ntuvs.uvb, ntuvs.ddxb, ntuvs.ddyb ), normalScale ), ntuvs.b.x ),
                 lerp( fixed3( ntuvs.ofc.z, ntuvs.ofc.w, 1 ) * UnpackNormalWithScale( tex2D( sampNorm, ntuvs.uvc, ntuvs.ddxc, ntuvs.ddyc ), normalScale ),
                       fixed3( ntuvs.ofd.z, ntuvs.ofd.w, 1 ) * UnpackNormalWithScale( tex2D( sampNorm, ntuvs.uvd, ntuvs.ddxd, ntuvs.ddyd ), normalScale ), ntuvs.b.x ), ntuvs.b.y );
}
