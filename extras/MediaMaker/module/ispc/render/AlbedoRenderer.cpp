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

#include "AlbedoRenderer.h"

// ospray
#include <ospray/SDK/lights/Light.h>

// ispc exports
#include "AlbedoRenderer_ispc.h"

using namespace ospray;

namespace bioexplorer
{
namespace mediamaker
{
namespace rendering
{
void AlbedoRenderer::commit()
{
    Renderer::commit();

    ispc::AlbedoRenderer_set(getIE(), spp);
}

AlbedoRenderer::AlbedoRenderer()
{
    ispcEquivalent = ispc::AlbedoRenderer_create(this);
}

OSP_REGISTER_RENDERER(AlbedoRenderer, albedo);
} // namespace rendering
} // namespace mediamaker
} // namespace bioexplorer