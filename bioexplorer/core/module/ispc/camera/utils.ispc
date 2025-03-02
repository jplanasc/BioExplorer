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


#include "utils.ih"

void clipRay(const uniform vec4f* clipPlanes, const unsigned int numClipPlanes,
             const varying vec3f& position, const varying vec3f& direction,
             varying float& near, varying float& far)
{
    for (int i = 0; i < numClipPlanes; ++i)
    {
        const vec3f normal = {clipPlanes[i].x, clipPlanes[i].y,
                              clipPlanes[i].z};
        const float d = clipPlanes[i].w;

        const float distance = dot(normal, position) + d;
        const float cosAngle = dot(direction, normal);

        if (cosAngle == 0.f)
        {
            // This ray is parallel to the plane, checking if position is
            // on the visible side
            if (distance < 0)
            {
                near = far = 0.f;
                return;
            }
        }
        else
        {
            const float t = -distance / cosAngle;
            if (cosAngle > 0.f) // same direction plane
                near = max(0.f, max(near, t));
            else
                far = max(0.f, min(far, t));
        }
    }
}
