/* similar to equi.js FIXME proj4 uses eqc */

// inverse equations--mapping x,y to lat/long
// -----------------------------------------------------------------
vec2 eqc_backwards(vec2 p, eqc_params params)
{
    float x = p.x;
    float y = p.y;

    p.x =
	adjust_lon(params.long0 +
		   ((x - params.x0) / (params.a * params.rc)));
    p.y = adjust_lat(params.lat0 + ((y - params.y0) / (params.a)));
    return p;
}

// vim:syntax=c:sw=4:sts=4:et
