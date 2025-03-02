/*
 * The Blue Brain BioExplorer is a tool for scientists to extract and analyse
 * scientific data from visualization
 *
 * Copyright 2020-2021 Blue BrainProject / EPFL
 *
 * This program is free software: you can redistribute it and/or modify it under
 * the terms of the GNU General Public License as published by the Free Software
 * Foundation, either version 3 of the License, or (at your option) any later
 * version.
 *
 * This program is distributed in the hope that it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
 * FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
 * details.
 *
 * You should have received a copy of the GNU General Public License along with
 * this program.  If not, see <https://www.gnu.org/licenses/>.
 */

#include <plugin/common/CommonTypes.h>

#include "AdvancedRenderer.ih"
#include "utils/BioExplorerSkyBox.ih"

/**
    Composes source and destination colors according to specified alpha
   correction
    @param src Source RGBA color
    @param dst Returned destination RGBA color
    @param alphaCorrection Alpha correction used to blend colors
*/
inline void composite(const varying vec4f& src, varying vec4f& dst,
                      const varying float alphaCorrection)
{
    const float alpha =
        1.f - pow(1.f - min(src.w, 1.f - 1.f / 256.f), alphaCorrection);
    const float a = alpha * (1.f - dst.w);
    dst.x = dst.x + src.x * a;
    dst.y = dst.y + src.y * a;
    dst.z = dst.z + src.z * a;
    dst.w += (alpha * (1.f - dst.w));
}

/**
    Returns the refracted vector according to the direction of the incident ray,
   he normal to the surface, and localRefraction indices
    @param direction Direction of the incident ray
    @param normal Normal to the surface
    @param n1 In localRefraction index
    @param n2 Out localRefraction index
    @return Refracted vector
*/
inline vec3f refractedVector(const varying vec3f& direction,
                             const varying vec3f& normal,
                             const varying float n1, const varying float n2)
{
    if (n2 == 0.f)
        return direction;
    const float eta = n1 / n2;
    const float cos1 = -dot(direction, normal);
    const float cos2 = 1.f - eta * eta * (1.f - cos1 * cos1);
    if (cos2 > 0.f)
        return eta * direction + (eta * cos1 - sqrt(cos2)) * normal;
    return direction;
}

struct ShadingAttributes
{
    const uniform AdvancedRenderer* uniform self;
    varying DifferentialGeometry* dg;
    vec4f bgColor;
    vec3f origin;
    vec3f normal;
    vec3f reflectedNormal;
    float refraction;
    float reflection;
    float opacity;
    float glossiness;
    vec3f diffuseColor;
    vec3f specularColor;
    float specularExponent;
    vec3f lightEmissionColor;
    float lightEmissionIntensity;
    float shadowIntensity;
    MaterialShadingMode shadingMode;
    float userParameter;
    MaterialChameleonMode chameleonMode;
    uint32 nodeId;
    vec3f indirectColor;
    float indirectIntensity;
    vec3f shadingContribution;
    vec3f finalContribution;
};

inline void initializeShadingAttributes(
    const uniform AdvancedRenderer* uniform self, ShadingAttributes& attributes)
{
    attributes.self = self;
    attributes.dg = 0;

    // Background color
    attributes.bgColor = make_vec4f(0.f);

    // Final contribution
    attributes.finalContribution = make_vec3f(0.f);

    // Indirect light contribution
    attributes.indirectColor = make_vec3f(0.f);
    attributes.indirectIntensity = 0.f;

    // Light emission
    attributes.lightEmissionColor = make_vec3f(0.f);
    attributes.lightEmissionIntensity = 0.f;

    // Shadows
    attributes.shadowIntensity = 0.f;

    // Diffuse color
    attributes.diffuseColor = make_vec3f(0.f);

    // Specular color
    attributes.specularColor = make_vec3f(0.f);
    attributes.specularExponent = 0.f;

    // Shading contribution
    attributes.shadingContribution = make_vec3f(0.f);

    // Other attributes
    attributes.reflection = 0.f;
    attributes.refraction = 1.f;
    attributes.opacity = 0.f;
    attributes.glossiness = 1.f;
}

inline void setGeometryShadingAttributes(
    const uniform AdvancedRenderer* uniform self, DifferentialGeometry& dg,
    varying ScreenSample& sample, const varying Ray& ray,
    ShadingAttributes& attributes)
{
    attributes.dg = &dg;

    // Intersection point with geometry
    attributes.origin = dg.P;

    // Shading normal
    attributes.normal = dg.Ns;

    // Shading mode
    attributes.shadingMode = undefined_shading_mode;

    // Reflected shading normal
    attributes.reflectedNormal =
        ray.dir - 2.f * dot(ray.dir, attributes.normal) * attributes.normal;

    // Chameleon
    attributes.chameleonMode = undefined_chameleon_mode;

    // Model Id
    attributes.nodeId = 0;

    // Process material attributes
    const uniform Material* material = dg.material;
    const uniform AdvancedMaterial* objMaterial =
        (const uniform AdvancedMaterial*)material;
    if (!objMaterial)
    {
        // Diffuse color
        attributes.diffuseColor = make_vec3f(dg.color);

        // if no material is defined, localOpacity is stored in the
        // alpha
        // component of the RGBA color
        attributes.opacity = dg.color.w;
        return;
    }

    foreach_unique(mat in objMaterial)
    {
        // Glossiness
        if (mat->glossiness < 1.f)
        {
            attributes.glossiness = mat->glossiness;
            const vec3f randomNormal =
                (1.f - mat->glossiness) *
                getRandomVector(self->useHardwareRandomizer,
                                self->super.fb->size.x, sample,
                                attributes.normal, self->randomNumber);
            attributes.normal = normalize(attributes.normal + randomNormal);
        }

        // Refraction index
        attributes.refraction = mat->refraction;

        // Opacity
        if (valid(mat->map_d))
            attributes.opacity = mat->d * get1f(mat->map_d, dg);
        else
            attributes.opacity = mat->d;

        // Diffuse color
        attributes.diffuseColor = mat->Kd * make_vec3f(dg.color);
        if (valid(mat->map_Kd))
        {
            const vec3f diffuseColorFromMap = get3f(mat->map_Kd, dg);
            attributes.diffuseColor =
                attributes.diffuseColor * make_vec3f(diffuseColorFromMap);
            // attributes.opacity *= diffuseColorFromMap.w;
        }

        // Specular color
        if (valid(mat->map_Ks))
            attributes.specularColor =
                max(attributes.specularColor, mat->Ks * get3f(mat->map_Ks, dg));
        else
            attributes.specularColor = max(attributes.specularColor, mat->Ks);

        // Specular exponent
        if (valid(mat->map_Ns))
            attributes.specularExponent = max(attributes.specularExponent,
                                              mat->Ns * get1f(mat->map_Ns, dg));
        else
            attributes.specularExponent =
                max(attributes.specularExponent, mat->Ns);

        // Light emission intensity
        attributes.lightEmissionIntensity += mat->a;
        attributes.lightEmissionColor = attributes.diffuseColor;

        // Normal mapping
        if (valid(mat->map_Bump))
        {
            const vec3f n = get3f(mat->map_Bump, dg, make_vec3f(0.f)) - 0.5f;
            attributes.normal.x -= n.x;
            attributes.normal.y -= n.y;
        }

        // Reflection index
        attributes.reflection = mat->reflection;
        if (valid(mat->map_reflection))
        {
            const vec3f value = get3f(mat->map_reflection, dg);
            attributes.reflection *= (value.x + value.y + value.z) / 3.f;
        }

        // Shading mode
        attributes.shadingMode = mat->shadingMode;

        // User parameter
        attributes.userParameter = mat->userParameter;

        // Chameleon mode
        attributes.chameleonMode = mat->chameleonMode;

        // Model Id
        attributes.nodeId = mat->nodeId;
    }

    // Update reflected shading normal
    attributes.reflectedNormal =
        ray.dir - 2.f * dot(ray.dir, attributes.normal) * attributes.normal;
}

inline bool launchRandomRay(
    const uniform AdvancedRenderer* uniform self, varying ScreenSample& sample,
    const varying vec3f& intersection, const varying vec3f& normal,
    varying vec3f& backgroundColor, varying float& distanceToIntersection,
    varying vec3f& randomDirection, varying vec3f& color,
    varying float& emission, const uint32 iteration, const float epsilon)
{
    randomDirection =
        getRandomVector(self->useHardwareRandomizer, self->super.fb->size.x,
                        sample, normal, iteration + self->randomNumber);
    backgroundColor = make_vec3f(0.f);

    if (dot(randomDirection, normal) < 0.f)
        // Invert direction of random ray direction is opposite to surface
        // normal
        randomDirection = neg(randomDirection);

    Ray randomRay;
    randomRay.org = intersection;
    randomRay.dir = randomDirection;
    randomRay.t0 = epsilon;
    randomRay.t = self->giDistance;
    randomRay.time = inf;
    randomRay.primID = -1;
    randomRay.geomID = -1;
    randomRay.instID = -1;

    bool moreRebounds = true;
    bool hit = false;
    while (moreRebounds)
    {
        traceRay(self->super.model, randomRay);

        if (randomRay.geomID < 0)
        {
            // No intersection
            backgroundColor =
                make_vec3f(skyboxMapping((Renderer*)self, randomRay,
                                         (AdvancedMaterial*)self->bgMaterial));
            return false;
        }

        DifferentialGeometry dg;
        postIntersect(self->super.model, dg, randomRay,
                      DG_NG | DG_NS | DG_NORMALIZE | DG_TANGENTS |
                          DG_FACEFORWARD | DG_MATERIALID | DG_COLOR |
                          DG_TEXCOORD);

        uniform AdvancedMaterial* objMaterial =
            (uniform AdvancedMaterial*)dg.material;
        if (objMaterial)
            foreach_unique(mat in objMaterial)
            {
                if (mat->chameleonMode != emitter)
                {
                    hit = true;
                    moreRebounds = false;

                    // Random ray hits a primitive
                    distanceToIntersection = randomRay.t * randomRay.t;

                    // Kd
                    if (valid(mat->map_Kd))
                        color = color + get3f(mat->map_Kd, dg);
                    else
                        color = color + mat->Kd;

                    // Emission
                    if (valid(mat->map_a))
                    {
                        vec3f Ka = get3f(mat->map_a, dg);
                        emission += reduce_max(Ka);
                    }
                    else
                        emission += mat->a;
                }
            }
        else
            moreRebounds = false;

        randomRay.t0 = randomRay.t + dg.epsilon;
        randomRay.t = inf;
        randomRay.primID = -1;
        randomRay.geomID = -1;
        randomRay.instID = -1;
    }

    return hit;
}

inline void indirectShading(const uniform AdvancedRenderer* uniform self,
                            varying ScreenSample& sample,
                            const varying vec3f& intersection,
                            const varying vec3f& normal,
                            varying vec3f& indirectColor,
                            varying float& indirectIntensity,
                            const float epsilon)
{
    if (self->giSamples == 0)
        return;

    vec3f backgroundColor = make_vec3f(0.f);
    float distanceToIntersection = inf;

    float shadingPower = 0.f;
    vec3f shadingColor = make_vec3f(0.f);

    for (uint32 i = 0; i < self->giSamples; ++i)
    {
        // Launch a random ray
        vec3f randomDirection;
        vec3f color = make_vec3f(0.f);
        float emission = 0.f;
        if (launchRandomRay(self, sample, intersection, normal, backgroundColor,
                            distanceToIntersection, randomDirection, color,
                            emission, i, epsilon))
        {
            // Kd
            shadingColor = shadingColor + color;

            // Emission
            shadingPower += 1.f + emission;
        }
        else
        {
            shadingColor = shadingColor + backgroundColor;
            shadingPower = shadingPower + DEFAULT_SKY_POWER;
        }
    }

    indirectColor = indirectColor + shadingColor / self->giSamples;
    indirectIntensity = indirectIntensity + shadingPower / self->giSamples;
}

inline float shadedLightIntensity(varying ScreenSample& sample,
                                  const varying Ray& ray,
                                  const ShadingAttributes& attributes,
                                  const varying vec3f& lightDirection,
                                  DifferentialGeometry& dg)
{
    float intensity = 0.f;

    const uint32 nbSamples = (attributes.self->softShadows > 0.f
                                  ? attributes.self->softShadowsSamples
                                  : 1);

    for (uint32 s = 0; s < nbSamples; ++s)
    {
        float shadowIntensity = 0.f;

        vec3f ld = lightDirection;
        if (attributes.self->softShadows > 0.f)
            // Slightly alter light direction for Soft shadows
            ld = normalize(
                ld + attributes.self->softShadows *
                         getRandomVector(attributes.self->useHardwareRandomizer,
                                         attributes.self->super.fb->size.x,
                                         sample, attributes.normal,
                                         s + attributes.self->randomNumber));

        if (dot(ld, lightDirection) < 0.f)
            ld = neg(ld);

        Ray shadowRay;
        shadowRay.org = dg.P;
        shadowRay.dir = ld;
        shadowRay.t0 = max(0.f, dg.epsilon);
        shadowRay.t = attributes.self->giDistance;
        shadowRay.time = inf;
        shadowRay.geomID = -1;
        shadowRay.primID = -1;
        shadowRay.instID = -1;

        while (shadowIntensity < 1.f)
        {
            traceRay(attributes.self->super.model, shadowRay);

            if (shadowRay.geomID == -1)
                break;

            DifferentialGeometry shadowingGeometry;
            postIntersect(attributes.self->super.model, shadowingGeometry,
                          shadowRay,
                          DG_NG | DG_NS | DG_NORMALIZE | DG_TANGENTS |
                              DG_FACEFORWARD | DG_MATERIALID | DG_COLOR |
                              DG_TEXCOORD);

            uniform AdvancedMaterial* objMaterial =
                (uniform AdvancedMaterial*)shadowingGeometry.material;

            float opacity = 1.f;

            if (objMaterial == 0)
                opacity = 1.f - shadowingGeometry.color.w;
            else
                foreach_unique(mat in objMaterial)
                {
                    if (mat->chameleonMode == emitter)
                        opacity = 0.f;
                    else
                    {
                        opacity = mat->d;
                        if (valid(mat->map_d))
                        {
                            vec4f d_map = get4f(mat->map_d, shadowingGeometry);
                            opacity = d_map.x;
                        }
                        else if (valid(mat->map_Kd))
                        {
                            vec4f localDiffuseColor_map =
                                get4f(mat->map_Kd, shadowingGeometry);
                            opacity = 1.f - localDiffuseColor_map.w;
                        }
                    }
                }

            shadowIntensity += opacity;

            shadowRay.t0 = max(0.f, shadowRay.t + shadowingGeometry.epsilon);
            shadowRay.t = inf;
            shadowRay.primID = -1;
            shadowRay.geomID = -1;
            shadowRay.instID = -1;
        }
        intensity += shadowIntensity;
    }
    intensity /= (float)nbSamples;

    return clamp(intensity * attributes.self->shadows, 0.f, 1.f);
}

inline void processBackgroundColor(varying ScreenSample& sample,
                                   const varying Ray& ray,
                                   ShadingAttributes& attributes)
{
    // No intersection. Return skybox color
    attributes.bgColor =
        skyboxMapping((Renderer*)attributes.self, ray,
                      (AdvancedMaterial*)attributes.self->bgMaterial);
    attributes.shadingContribution = make_vec3f(attributes.bgColor);
}

inline void computeIndirectShading(DifferentialGeometry& dg,
                                   varying ScreenSample& sample,
                                   ShadingAttributes& attributes)

{
    indirectShading(attributes.self, sample, attributes.origin,
                    attributes.normal, attributes.indirectColor,
                    attributes.indirectIntensity, dg.epsilon);
}

inline void processShadows(DifferentialGeometry& dg,
                           varying ScreenSample& sample, const varying Ray& ray,
                           ShadingAttributes& attributes)
{
    for (uniform uint32 i = 0; i < attributes.self->numLights; ++i)
    {
        const uniform Light* uniform light = attributes.self->lights[i];
        const vec2f samplingLocation = make_vec2f(0.5f);
        const varying Light_SampleRes lightSample =
            light->sample(light, dg, samplingLocation);
        const vec3f lightColor = lightSample.weight;
        const float radiance = reduce_max(lightColor);
        const vec3f lightDirection = lightSample.dir;

        if (radiance <= 0.f)
            continue;

        attributes.shadowIntensity +=
            shadedLightIntensity(sample, ray, attributes, lightDirection, dg);
    }

    if (attributes.shadowIntensity > 0.f)
        // Remove specular color if surface is in the shades
        attributes.specularColor = make_vec3f(0.f);
}

inline vec3f getChameleonColor(const uniform AdvancedRenderer* uniform self,
                               DifferentialGeometry& dg,
                               varying ScreenSample& sample,
                               ShadingAttributes& attributes)
{
    vec3f shadingColor = make_vec3f(0.f);
    size_t hits = 0;
    for (uint32 i = 0; i < 20; ++i)
    {
        const vec3f randomDirection =
            getRandomVector(self->useHardwareRandomizer, self->super.fb->size.x,
                            sample, neg(attributes.normal),
                            i + self->randomNumber);
        Ray ray;
        ray.org = attributes.origin + randomDirection * dg.epsilon;
        ray.dir = randomDirection;
        ray.t0 = max(0.f, dg.epsilon);
        ray.t = self->giDistance;
        ray.time = inf;
        ray.primID = -1;
        ray.geomID = -1;
        ray.instID = -1;

        traceRay(self->super.model, ray);

        if (ray.geomID >= 0)
        {
            // Get intersection information
            DifferentialGeometry geometry;
            postIntersect(self->super.model, geometry, ray,
                          DG_NG | DG_NS | DG_NORMALIZE | DG_FACEFORWARD |
                              DG_TANGENTS | DG_MATERIALID | DG_COLOR |
                              DG_TEXCOORD);

            const uniform Material* material = geometry.material;
            const uniform AdvancedMaterial* objMaterial =
                (const uniform AdvancedMaterial*)material;
            if (objMaterial)
            {
                foreach_unique(mat in objMaterial)
                {
                    if (mat->chameleonMode == emitter &&
                        mat->nodeId == attributes.nodeId)
                    {
                        if (valid(mat->map_Kd))
                            shadingColor =
                                shadingColor + get3f(mat->map_Kd, geometry);
                        else
                            shadingColor = shadingColor + mat->Kd;
                        ++hits;
                    }
                }
            }
        }
    }
    if (hits == 0)
        return shadingColor;
    return shadingColor / hits;
}

inline void processLightShading(const uniform AdvancedRenderer* uniform self,
                                DifferentialGeometry& dg,
                                varying ScreenSample& sample,
                                const varying Ray& ray,
                                ShadingAttributes& attributes)
{
    // Shading for all lights defined in the scene
    attributes.shadingContribution = make_vec3f(0.f);

    vec3f accDiffuse = make_vec3f(0.f);
    vec3f accSpecular = make_vec3f(0.f);

    for (uniform uint32 i = 0; i < attributes.self->numLights; ++i)
    {
        const uniform Light* uniform light = attributes.self->lights[i];
        const vec2f samplingLocation = make_vec2f(0.5f);
        const varying Light_SampleRes lightSample =
            light->sample(light, dg, samplingLocation);
        const vec3f lightColor = lightSample.weight;
        const float radiance = reduce_max(lightColor);

        if (radiance <= 0.f)
            continue;

        const vec3f lightDirection = lightSample.dir;
        float cosNL = 1.f;

        if (attributes.shadingMode != undefined_shading_mode)
        {
            // Phong + Blinn shading
            if (attributes.shadingMode != perlin)
                cosNL = max(0.f, dot(lightDirection, attributes.normal));

            // Specular color
            const float cosLR = dot(lightDirection, attributes.reflectedNormal);
            accSpecular = accSpecular +
                          lightColor * powf(cosLR, attributes.specularExponent);
        }

        accDiffuse =
            accDiffuse + (lightColor * cosNL * attributes.diffuseColor);

        if (attributes.shadingMode == diffuse_transparency)
            attributes.opacity *= sqrt(cosNL);
    }

    // Process light contribution
    attributes.specularColor = accSpecular;
    attributes.shadingContribution = accDiffuse;
}

inline void processDiffuseShading(const uniform AdvancedRenderer* uniform self,
                                  DifferentialGeometry& dg,
                                  varying ScreenSample& sample,
                                  const varying Ray& ray,
                                  ShadingAttributes& attributes)
{
    if (attributes.chameleonMode == receiver)
        attributes.diffuseColor =
            getChameleonColor(self, dg, sample, attributes);

    processLightShading(self, dg, sample, ray, attributes);
}

inline void processBasicShading(const uniform AdvancedRenderer* uniform self,
                                DifferentialGeometry& dg,
                                varying ScreenSample& sample,
                                ShadingAttributes& attributes)
{
    const vec3f viewer = normalize(sample.ray.org - attributes.origin);
    const float el = max(0.f, dot(viewer, attributes.normal));
    const float cosNL = pow(el, attributes.userParameter);

    if (attributes.chameleonMode == receiver)
        attributes.diffuseColor =
            getChameleonColor(self, dg, sample, attributes);

    attributes.shadingContribution = cosNL * attributes.diffuseColor;
    attributes.specularColor = make_vec3f(0.f);
}

inline void processElectronShading(const uniform AdvancedRenderer* uniform self,
                                   DifferentialGeometry& dg,
                                   varying ScreenSample& sample,
                                   ShadingAttributes& attributes)
{
    const vec3f viewer = normalize(sample.ray.org - attributes.origin);
    const float el = max(0.f, dot(viewer, attributes.normal));
    const float cosNL = 1.f - pow(el, attributes.userParameter);

    if (attributes.chameleonMode == receiver)
        attributes.diffuseColor =
            getChameleonColor(self, dg, sample, attributes);

    attributes.shadingContribution = cosNL * attributes.diffuseColor;
    attributes.specularColor = make_vec3f(0.f);
}

inline void processElectronTransparencyShading(
    const uniform AdvancedRenderer* uniform self, DifferentialGeometry& dg,
    varying ScreenSample& sample, ShadingAttributes& attributes)
{
    const vec3f viewer = normalize(sample.ray.org - attributes.origin);
    const float el = 1.f - max(0.f, dot(viewer, attributes.normal));
    const float cosNL = 1.f - pow(el, attributes.userParameter);

    if (attributes.chameleonMode == receiver)
        attributes.diffuseColor =
            getChameleonColor(self, dg, sample, attributes);

    attributes.shadingContribution = cosNL * attributes.diffuseColor;
    attributes.specularColor = make_vec3f(0.f);
    attributes.opacity *= cosNL;
}

inline void processCartoonShading(const uniform AdvancedRenderer* uniform self,
                                  DifferentialGeometry& dg,
                                  varying ScreenSample& sample,
                                  ShadingAttributes& attributes)
{
    const vec3f viewer = normalize(sample.ray.org - attributes.origin);
    float cosNL = max(0.f, dot(viewer, attributes.normal));
    const uint32 angleAsInt = cosNL * attributes.userParameter;
    cosNL = (float)(angleAsInt) / attributes.userParameter;

    if (attributes.chameleonMode == receiver)
        attributes.diffuseColor =
            getChameleonColor(self, dg, sample, attributes);

    attributes.shadingContribution = cosNL * attributes.diffuseColor;
    attributes.specularColor = make_vec3f(0.f);
}

inline void processNoiseShading(const uniform AdvancedRenderer* uniform self,
                                DifferentialGeometry& dg,
                                varying ScreenSample& sample,
                                const varying Ray& ray,
                                ShadingAttributes& attributes)
{
    vec3f point = attributes.userParameter * dg.P;

    const float n1 = 0.25f + 0.75f * clamp(worleyNoise(point, 2.f), 0.f, 1.f);

    if (attributes.chameleonMode == receiver)
        attributes.diffuseColor =
            getChameleonColor(self, dg, sample, attributes);

    attributes.diffuseColor = (1.f - n1) * attributes.diffuseColor;
    attributes.specularColor = (1.f - n1) * attributes.specularColor;

    attributes.normal.x += 0.5f * n1;
    attributes.normal.y += 0.5f * (0.5f - n1);
    attributes.normal.z += 0.5f * (0.25f - n1);
    attributes.normal = normalize(attributes.normal);

    attributes.reflectedNormal =
        ray.dir - 2.f * dot(ray.dir, attributes.normal) * attributes.normal;

    processLightShading(self, dg, sample, ray, attributes);
}

inline void processCheckerShading(const uniform AdvancedRenderer* uniform self,
                                  DifferentialGeometry& dg,
                                  varying ScreenSample& sample,
                                  const varying Ray& ray,
                                  ShadingAttributes& attributes)
{
    if (attributes.chameleonMode == receiver)
        attributes.diffuseColor =
            getChameleonColor(self, dg, sample, attributes);

    const vec3i point =
        make_vec3i(attributes.userParameter * (dg.P + make_vec3f(1e2f)));
    const vec3i p = make_vec3i(point.x % 2, point.y % 2, point.z % 2);
    if ((p.x == p.y && p.z == 1) || (p.x != p.y && p.z == 0))
    {
        attributes.diffuseColor = make_vec3f(1.f) - attributes.diffuseColor;
        attributes.specularColor = make_vec3f(1.f) - attributes.specularColor;
    }
    processLightShading(self, dg, sample, ray, attributes);
}

inline void processGoodsellShading(const uniform AdvancedRenderer* uniform self,
                                   DifferentialGeometry& dg,
                                   varying ScreenSample& sample,
                                   ShadingAttributes& attributes)
{
    const vec3f viewer = normalize(sample.ray.org - attributes.origin);
    const float cosNL = max(0.f, dot(viewer, attributes.normal));

    if (attributes.chameleonMode == receiver)
        attributes.diffuseColor =
            getChameleonColor(self, dg, sample, attributes);

    attributes.shadingContribution =
        (cosNL > attributes.userParameter ? attributes.diffuseColor
                                          : attributes.diffuseColor / 2.f);
    attributes.specularColor = make_vec3f(0.f);
}

inline void processFinalContribution(ShadingAttributes& attributes)
{
    // Surface shading
    vec3f totalContributions =
        attributes.shadingContribution + attributes.specularColor;

    // Shadow contribution
    totalContributions =
        totalContributions * make_vec3f(1.f - attributes.shadowIntensity);

    // Indirect light contribution
    totalContributions =
        totalContributions +
        attributes.self->giStrength *
            (attributes.indirectColor * attributes.indirectIntensity);

    // Light emission contribution
    totalContributions =
        totalContributions +
        attributes.lightEmissionIntensity * attributes.lightEmissionColor;

    // Store final contribution
    attributes.finalContribution =
        clamp(totalContributions, make_vec3f(0.f), make_vec3f(1.f));
}

inline vec3f AdvancedRenderer_shadeRay(
    const uniform AdvancedRenderer* uniform self, varying ScreenSample& sample)
{
    Ray ray = sample.ray;
    vec4f color = make_vec4f(0.f);
    vec3f bgColor = make_vec3f(0.f);
    if (self->showBackground)
        bgColor =
            make_vec3f(skyboxMapping((Renderer*)self, ray,
                                     (AdvancedMaterial*)self->bgMaterial));

    uint32 depth = 0;
    float oldlocalRefraction = 1.f;

    sample.z = inf;
    bool moreRebounds = true;

    while (moreRebounds && depth < self->maxBounces && color.w < 0.95f)
    {
        float totalOpacity = 0.f;

        // Shading attributes store all color contributions for the
        // current ray
        ShadingAttributes attributes;
        initializeShadingAttributes(self, attributes);

        // Trace ray
        traceRay(self->super.model, ray);

        if (ray.geomID < 0)
        {
            if (self->showBackground)
            {
                processBackgroundColor(sample, ray, attributes);
                bgColor = make_vec3f(attributes.bgColor);
            }
            moreRebounds = false;
        }
        else
        {
            DifferentialGeometry dg;
            postIntersect(self->super.model, dg, ray,
                          DG_NG | DG_NS | DG_NORMALIZE | DG_TANGENTS |
                              DG_FACEFORWARD | DG_MATERIALID | DG_COLOR |
                              DG_TEXCOORD);

            // Get intersection information
            // Initialize geometry shading attributes
            setGeometryShadingAttributes(self, dg, sample, ray, attributes);

            if (attributes.chameleonMode == emitter)
                ray.t0 = ray.t + dg.epsilon;
            else
            {
                if (sample.sampleID.z > 0)
                    // Compute indirect lighting contribution
                    computeIndirectShading(dg, sample, attributes);

                // Compute surface shading
                if (attributes.shadingMode == basic)
                    processBasicShading(self, dg, sample, attributes);
                else if (attributes.shadingMode == electron)
                    processElectronShading(self, dg, sample, attributes);
                else if (attributes.shadingMode == cartoon)
                    processCartoonShading(self, dg, sample, attributes);
                else if (attributes.shadingMode == electron_transparency)
                    processElectronTransparencyShading(self, dg, sample,
                                                       attributes);
                else if (attributes.shadingMode == perlin)
                    processNoiseShading(self, dg, sample, ray, attributes);
                else if (attributes.shadingMode == checker)
                    processCheckerShading(self, dg, sample, ray, attributes);
                else if (attributes.shadingMode == goodsell)
                    processGoodsellShading(self, dg, sample, attributes);
                else
                    processDiffuseShading(self, dg, sample, ray, attributes);

                // Compute shadows
                if (sample.sampleID.z > 0 && self->shadows > 0.f)
                    processShadows(dg, sample, ray, attributes);

                // Z-Depth
                if (depth == 0)
                    sample.z = ray.t;

                // Alpha
                totalOpacity +=
                    (1.f - attributes.reflection) * attributes.opacity;

                // Prepare ray for next iteration
                bool doRefraction = (attributes.opacity < 1.f);
                bool doReflection = (attributes.reflection > 0.f);
                if (doRefraction && doReflection)
                {
                    // Switch between refraction and reflection
                    const bool reflect = sample.sampleID.z % 4 == 1;
                    doRefraction = !reflect;
                    doReflection = reflect;
                }

                if (doRefraction)
                {
                    // Refraction
                    ray.dir = refractedVector(ray.dir, attributes.normal,
                                              oldlocalRefraction,
                                              attributes.refraction);
                    oldlocalRefraction = attributes.refraction;
                }
                else if (doReflection)
                    // Reflection
                    ray.dir = attributes.reflectedNormal;

                // Combine all contributions
                processFinalContribution(attributes);

                composite(make_vec4f(attributes.finalContribution,
                                     totalOpacity),
                          color, 1.0f);

                // Prepare next ray
                ray.org = dg.P + ray.dir * dg.epsilon;
                ray.t0 = max(0.f, dg.epsilon);
                ++depth;
            }

            ray.t = inf - ray.t;
            ray.primID = -1;
            ray.geomID = -1;
            ray.instID = -1;
        }
    }

    // Fog attenuation
    const float fogAttenuation =
        sample.z > self->fogStart
            ? clamp((sample.z - self->fogStart) / self->fogThickness, 0.f, 1.f)
            : 0.f;
    const float fog = 1.f - color.w * (1.f - fogAttenuation);

    // Final color
    const vec3f finalColor = make_vec3f(color) * (1.f - fog) + fog * bgColor;
    sample.alpha = min(1.f, color.w);
    return make_vec3f(finalColor * self->exposure);
}

void AdvancedRenderer_renderSample(uniform Renderer* uniform _self,
                                   void* uniform perFrameData,
                                   varying ScreenSample& sample)
{
    uniform AdvancedRenderer* uniform self =
        (uniform AdvancedRenderer * uniform) _self;
    sample.ray.time = inf;
    sample.rgb = AdvancedRenderer_shadeRay(self, sample);
}

// Exports (called from C++)
export void* uniform AdvancedRenderer_create(void* uniform cppE)
{
    uniform AdvancedRenderer* uniform self =
        uniform new uniform AdvancedRenderer;
    Renderer_Constructor(&self->super, cppE);
    self->super.renderSample = AdvancedRenderer_renderSample;
    return self;
}

export void AdvancedRenderer_set(
    void* uniform _self, void* uniform bgMaterial, const uniform float shadows,
    const uniform float softShadows, const uniform uint32 softShadowsSamples,
    const uniform float giStrength, const uniform float giDistance,
    const uniform uint32 giSamples, const uniform uint32 randomNumber,
    const uniform float timestamp, const uniform uint32 spp,
    void** uniform lights, const uniform uint32 numLights,
    const uniform float exposure, const uniform float fogThickness,
    const uniform float fogStart, const uniform bool useHardwareRandomizer,
    const uniform uint32 maxBounces, const uniform bool showBackground)
{
    uniform AdvancedRenderer* uniform self =
        (uniform AdvancedRenderer * uniform) _self;

    // OSPRay
    self->super.spp = spp;

    self->lights = (const uniform Light* uniform* uniform)lights;
    self->numLights = numLights;

    // Bio explorer
    self->bgMaterial = (uniform AdvancedMaterial * uniform) bgMaterial;

    self->timestamp = timestamp;
    self->exposure = exposure;
    self->useHardwareRandomizer = useHardwareRandomizer;
    self->showBackground = showBackground;

    self->fogThickness = fogThickness;
    self->fogStart = fogStart;

    self->shadows = shadows;
    self->softShadows = softShadows;
    self->softShadowsSamples = softShadowsSamples;

    self->giStrength = giStrength;
    self->giDistance = giDistance;
    self->giSamples = giSamples;

    self->randomNumber = randomNumber;
    self->maxBounces = maxBounces;
}
