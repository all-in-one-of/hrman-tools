/*
 * PROPRIETARY INFORMATION.  This software is proprietary to
 * Side Effects Software Inc., and is not to be reproduced,
 * transmitted, or disclosed in any way without written permission.
 *
 * Produced by:
 *	Side Effects Software Inc
 *	123 Front Street West, Suite 1401
 *	Toronto, Ontario
 *	Canada   M5J 2M2
 *	416-504-9876
 *
 * NAME:	h_gilight.sl ( RenderMan SL )
 *
 * COMMENTS:
 */

#define HOU_INFINITY 1e+16

light h_gilight
        (
                color lightcolor = 1.0;

                float samplingquality = 1;
                float render_domaxdist = 0;
                float render_maxdist = 10.0;
                float render_angle = 1.5707963267948966; //Angle measured in radians.
                float render_doadaptive = 0;

                output varying color _diffuselight = 0.0;

                output float __nondiffuse = 0;
                output float __nonspecular = 1;
                output string __category = "indirectlight";
        )
{


    normal nN = normalize(N);

    illuminate(Ps + nN)
    {
        Cl = 0;

        color irrad = 0;

        if(samplingquality > 0)
        {
            float locmaxdist = (render_domaxdist > 0.5) ? render_maxdist : HOU_INFINITY;
            
            irrad = indirectdiffuse(Ps, nN, samplingquality,
                                    "coneangle", render_angle,
                                    "maxdist", locmaxdist,
                                    "hitmode", "shader",
                                    "adaptive", render_doadaptive);
        }

        _diffuselight = irrad * lightcolor;

        // Modify Ci if the surface isn't GI aware
        float aware = 0;
        surface("_gi_aware", aware);
        if( aware < 1 )
            {Cl = _diffuselight;}
    }
}
