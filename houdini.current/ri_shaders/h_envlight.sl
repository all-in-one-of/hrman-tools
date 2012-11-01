
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
 * NAME:	h_envlight.sl ( RenderMan SL )
 *
 * COMMENTS:
 */

#define HOU_INFINITY 1e+16

float
fit(float val, omin, omax, nmin, nmax)
{
    float	t;
    t = clamp((val - omin)/(omax - omin), 0, 1);
    return mix(nmin, nmax, t);
}
    
color
fit(color v, s0, s1, d0, d1)
{
    return color(fit(comp(v,0), comp(s0,0), comp(s1,0), comp(d0,0), comp(d1,0)),
        fit(comp(v,1), comp(s0,1), comp(s1,1), comp(d0,1), comp(d1,1)),
        fit(comp(v,2), comp(s0,2), comp(s1,2), comp(d0,2), comp(d1,2)));
}

light h_envlight
        (
                vector env_rotate = 0.0; // Euler rotations converted to radians
                color lightcolor = 1.0;
                string env_map = "";
                float env_clipy = 0; //This isn't being used for anything yet.
                
                /*"background" not the same as mantra; it will attempt to 
                raytrace the scene. This may be good for legacy RSL surface 
                shaders that lack raytracing. "occlusion" will turn off 
                specular, just like Mantra does for the env light.*/
                string env_mode = "direct";
                float samplingquality = 1;
                float env_domaxdist = 0;
                float env_maxdist = 10.0;
                float env_angle = PI/2; //Measured in radians.
                float env_doadaptive = 0;
                string shadow_type = "raytrace";
                float shadow_intensity = 1.0;
                float shadow_transparent = 1;

                output varying color _diffuselight = 0.0;
                output varying color _specularlight = 0.0;

                output varying float __nondiffuse = 0;
                output varying float __nonspecular = 0;
                output string __category = "indirectlight";
        )
{
    vector ldir = L;
    normal nN = normalize(N);
    vector nI = normalize(I);
    color shadow_color = 1;

    matrix objspace = matrix "object"(1);
    objspace = rotate(objspace, xcomp(env_rotate), vector(1,0,0));
    objspace = rotate(objspace, ycomp(env_rotate), vector(0,1,0));
    objspace = rotate(objspace, zcomp(env_rotate), vector(0,0,1));
    
    vector camrefl = reflect(nI, nN);
    vector objvec = vtransform(objspace, camrefl);
       
    normal objnml = ntransform(objspace, nN);
    vector Rvec = objnml;

    illuminate(Ps + nN)
    {
    
   
    /*******************************************************/
    /* If specular is enabled. */
    /*******************************************************/
        
        if(__nonspecular < 1 && env_mode != "occlusion")
        {
            color irradspec = 0;
            
            string loc_env_map = (env_mode == "background") ? "raytrace": env_map;
    
            if(loc_env_map != "") /* Compute environment map. */
            {
                irradspec = color environment(loc_env_map, objvec);
                _specularlight = lightcolor  * irradspec;
            }
            else // When there is no environment map then we return a flat color
            {
                _specularlight = lightcolor ;
            }
    
        }
    
    
    /*******************************************************/
    /* If diffuse is enabled. */
    /*******************************************************/
        
        if(__nondiffuse < 1)
        {
            color irraddiff = 0;
            
            string loc_env_map = (env_mode == "background") ? "raytrace": env_map;
            
            if(loc_env_map != "") /* Compute environment map. */
            {   
                float blur = (env_mode == "occlusion") ? env_angle : PI/2 ;
                vector rayvec = Rvec;

                gather("samplepattern", Ps, Rvec, blur, samplingquality,"ray:direction", rayvec)
                {}
                else
                {
                        irraddiff += color environment(loc_env_map, rayvec);
                }
                
                irraddiff /= samplingquality;

                _diffuselight = lightcolor  * irraddiff;
            }
            else // When there is no environment map then we return a flat color
            {
                _diffuselight = lightcolor ;
            }
            
            /* Compute occlusion. */
            if(env_mode == "occlusion")
            {
                float locmaxdist = (env_domaxdist != 0) ? env_maxdist : HOU_INFINITY;
                
                shadow_color = 1 - occlusion(Ps, nN, samplingquality,
                                        "coneangle", env_angle,
                                        "maxdist", locmaxdist,
                                        "hitmode", "shader",
                                        "adaptive", env_doadaptive);
            }
        }

        if(shadow_type == "raytrace" && env_mode != "occlusion" && 
        shadow_intensity > 0 && (__nonspecular < 1 || __nondiffuse < 1))
        {
                string hitmode = "shader";
                if(shadow_transparent < 0.5)
                        {hitmode = "primitive";}

                shadow_color = transmission(Ps, Ps + nN * HOU_INFINITY, 
                    "samples", samplingquality,"samplecone", PI/2, "hitmode", hitmode);

                shadow_color = fit(shadow_color, color(0), color(1), 
                    color(1 - min(shadow_intensity, 1)), color(1));
        }
        _diffuselight *= shadow_color;
        _specularlight *= shadow_color;
        
        
        // Set light color to black
        Cl = 0;
        
        // Modify Ci if the surface isn't GI aware
        float aware = 0;
        surface("_gi_aware", aware);
        if( aware < 1 )
            {Cl = _diffuselight + _specularlight;}
    }
}
