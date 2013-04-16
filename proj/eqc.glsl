/* similar to equi.js FIXME proj4 uses eqc */

// forward equations--mapping lat,long to x,y
// -----------------------------------------------------------------
vec2 eqc_forwards(vec2 p, eqc_params params)
{
    float lon = p.x;
    float lat = p.y;

    float dlon = adjust_lon(lon - params.long0);
    float dlat = adjust_lat(lat - params.lat0);
    p.x = params.x0 + (params.a * dlon * params.rc);
    p.y = params.y0 + (params.a * dlat);
    return p;
}

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
