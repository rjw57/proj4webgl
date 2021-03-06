/*******************************************************************************
NAME                    LAMBERT CYLINDRICAL EQUAL AREA

PURPOSE:	Transforms input longitude and latitude to Easting and
		Northing for the Lambert Cylindrical Equal Area projection.
                This class of projection includes the Behrmann and 
                Gall-Peters Projections.  The
		longitude and latitude must be in radians.  The Easting
		and Northing values will be returned in meters.

PROGRAMMER              DATE            
----------              ----
R. Marsden              August 2009
Winwaed Software Tech LLC, http://www.winwaed.com

This function was adapted from the Miller Cylindrical Projection in the Proj4JS
library.

Note: This implementation assumes a Spherical Earth. The (commented) code 
has been included for the ellipsoidal forward transform, but derivation of 
the ellispoidal inverse transform is beyond me. Note that most of the 
Proj4JS implementations do NOT currently support ellipsoidal figures. 
Therefore params.is not seen as a problem - especially params.lack of support 
is explicitly stated here.
 
ALGORITHM REFERENCES

1.  "Cartographic Projection Procedures for the UNIX Environment - 
     A User's Manual" by Gerald I. Evenden, USGS Open File Report 90-284
    and Release 4 Interim Reports (2003)

2.  Snyder, John P., "Flattening the Earth - Two Thousand Years of Map 
    Projections", Univ. Chicago Press, 1993
*******************************************************************************/

/* Cylindrical Equal Area forward equations--mapping lat,long to x,y
   ------------------------------------------------------------*/
vec2 cea_forwards(vec2 p, cea_params params)
{
    float lon = p.x;
    float lat = p.y;
    float x, y;
    /* Forward equations
       ----------------- */
    float dlon = adjust_lon(lon - params.long0);
    if (0 != params.sphere) {
	x = params.x0 + params.a * dlon * cos(params.lat_ts);
	y = params.y0 + params.a * sin(lat) / cos(params.lat_ts);
    } else {
	float qs = qsfnz(params.e, sin(lat));
	x = params.x0 + params.a * params.k0 * dlon;
	y = params.y0 + params.a * qs * 0.5 / params.k0;
    }

    p.x = x;
    p.y = y;
    return p;
}				//ceaFwd()

/* Cylindrical Equal Area inverse equations--mapping x,y to lat/long
------------------------------------------------------------*/
vec2 cea_backwards(vec2 p, cea_params params)
{
    p.x -= params.x0;
    p.y -= params.y0;
    float lon, lat;
    
    if (0 != params.sphere){
	lon = adjust_lon( params.long0 + (p.x / params.a) / cos(params.lat_ts) );
        lat = asin( (p.y/params.a) * cos(params.lat_ts) );
    } else {
	lat=iqsfnz(params.e,2.0*p.y*params.k0/params.a);
	lon = adjust_lon( params.long0 + p.x/(params.a*params.k0));
    }

    p.x=lon;
    p.y=lat;
    return p;
}				//ceaInv()

// vim:syntax=c:sw=4:sts=4:et
