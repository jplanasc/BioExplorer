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

#include "FieldsHandler.h"
#include "Octree.h"

#include <plugin/common/Logs.h>
#include <plugin/common/Utils.h>

#include <brayns/common/scene/ClipPlane.h>
#include <brayns/engineapi/Model.h>

#include <fstream>

namespace bioexplorer
{
namespace fields
{
using namespace common;

FieldsHandler::FieldsHandler(const Scene& scene, const float voxelSize,
                             const float density)
    : AbstractSimulationHandler()
{
    // Load simulation information from compartment reports
    _dt = 1.f;
    _nbFrames = 1;
    _unit = "microns";
    _frameSize = 1;
    _buildOctree(scene, voxelSize, density);
}

FieldsHandler::FieldsHandler(const std::string& filename)
    : AbstractSimulationHandler()
{
    // Import octree from file
    importFromFile(filename);
    _dt = 1.f;
    _nbFrames = 1;
    _unit = "microns";
}

void FieldsHandler::_buildOctree(const Scene& scene, const float voxelSize,
                                 const float density)
{
    PLUGIN_INFO("Building Octree");

    if (density > 1.f || density <= 0.f)
        PLUGIN_THROW("Density should be higher > 0 and <= 1");
    const size_t densityRatio = 1.f / density;

    const auto clipPlanes = getClippingPlanes(scene);

    floats events;
    uint16_t count;

    const auto& modelDescriptors = scene.getModelDescriptors();
    for (const auto modelDescriptor : modelDescriptors)
    {
        const auto& instances = modelDescriptor->getInstances();
        for (const auto& instance : instances)
        {
            const auto& tf = instance.getTransformation();
            const auto& model = modelDescriptor->getModel();
            const auto& spheresMap = model.getSpheres();
            for (const auto& spheres : spheresMap)
            {
                for (const auto& sphere : spheres.second)
                {
                    const Vector3d center =
                        tf.getTranslation() +
                        tf.getRotation() *
                            (Vector3d(sphere.center) - tf.getRotationCenter());

                    const Vector3f c = center;
                    if (isClipped(c, clipPlanes))
                        continue;

                    if (count % densityRatio == 0)
                    {
                        events.push_back(c.x);
                        events.push_back(c.y);
                        events.push_back(c.z);
                        events.push_back(sphere.radius);
                        events.push_back(sphere.radius);
                    }
                    ++count;
                }
            }
        }
    }

    // Determine model bounding box
    glm::vec3 minAABB(std::numeric_limits<float>::max(),
                      std::numeric_limits<float>::max(),
                      std::numeric_limits<float>::max());
    glm::vec3 maxAABB(-std::numeric_limits<float>::max(),
                      -std::numeric_limits<float>::max(),
                      -std::numeric_limits<float>::max());
    for (uint64_t i = 0; i < events.size(); i += 5)
    {
        if (events[i + 4] != 0.f)
        {
            minAABB = {std::min(minAABB.x, events[i]),
                       std::min(minAABB.y, events[i + 1]),
                       std::min(minAABB.z, events[i + 2])};
            maxAABB = {std::max(maxAABB.x, events[i]),
                       std::max(maxAABB.y, events[i + 1]),
                       std::max(maxAABB.z, events[i + 2])};
        }
    }

    // Compute volume information
    const glm::vec3 sceneSize = maxAABB - minAABB;

    // Double AABB size
    glm::vec3 center = (minAABB + maxAABB) / 2.f;
    minAABB = center - sceneSize * 0.5f;
    maxAABB = center + sceneSize * 0.5f;
    _offset = minAABB;

    // Build acceleration structure
    Octree morphoOctree(events, voxelSize, minAABB, maxAABB);
    uint64_t volumeSize = morphoOctree.getVolumeSize();
    _offset = minAABB;
    _dimensions = morphoOctree.getVolumeDim();
    _spacing = sceneSize / glm::vec3(_dimensions);

    PLUGIN_INFO("--------------------------------------------");
    PLUGIN_INFO("Octree information");
    PLUGIN_INFO("--------------------------------------------");
    PLUGIN_INFO("Scene AABB        : ["
                << minAABB.x << "," << minAABB.y << "," << minAABB.z << "] ["
                << maxAABB.x << "," << maxAABB.y << "," << maxAABB.z << "]");
    PLUGIN_INFO("Scene dimension   : [" << sceneSize.x << "," << sceneSize.y
                                        << "," << sceneSize.z << "]");
    PLUGIN_INFO("Element spacing   : [" << _spacing.x << ", " << _spacing.y
                                        << ", " << _spacing.z << "] ");
    PLUGIN_INFO("Volume dimensions : ["
                << _dimensions.x << ", " << _dimensions.y << ", "
                << _dimensions.z << "] = " << volumeSize << " bytes");
    PLUGIN_INFO("Element offset    : [" << _offset.x << ", " << _offset.y
                                        << ", " << _offset.z << "] ");

    const auto& indices = morphoOctree.getFlatIndexes();
    PLUGIN_INFO("Indices size      : " << indices.size());
    const auto& data = morphoOctree.getFlatData();
    _frameData.push_back(_offset.x);
    _frameData.push_back(_offset.y);
    _frameData.push_back(_offset.z);
    _frameData.push_back(_spacing.x);
    _frameData.push_back(_spacing.y);
    _frameData.push_back(_spacing.z);
    _frameData.push_back(_dimensions.x);
    _frameData.push_back(_dimensions.y);
    _frameData.push_back(_dimensions.z);
    _frameData.push_back(morphoOctree.getOctreeSize());
    _frameData.push_back(indices.size());
    _frameData.insert(_frameData.end(), indices.begin(), indices.end());
    _frameData.insert(_frameData.end(), data.begin(), data.end());
    _frameSize = _frameData.size();
    PLUGIN_INFO("Data size         : " << _frameSize);
    PLUGIN_INFO("--------------------------------------------");
}

FieldsHandler::FieldsHandler(const FieldsHandler& rhs)
    : AbstractSimulationHandler(rhs)
{
}

FieldsHandler::~FieldsHandler() {}

void* FieldsHandler::getFrameData(const uint32_t frame)
{
    if (_currentFrame == frame)
        return 0;
    _currentFrame = frame;
    return _frameData.data();
}

const void FieldsHandler::exportToFile(const std::string& filename) const
{
    PLUGIN_INFO("Saving octree to file: " << filename);
    std::ofstream file(filename, std::ios::out | std::ios::binary);
    if (!file.good())
        PLUGIN_THROW("Could not export octree to " + filename);

    file.write((char*)&_frameSize, sizeof(uint64_t));
    file.write((char*)_frameData.data(), _frameData.size() * sizeof(float));

    file.close();
}

void FieldsHandler::importFromFile(const std::string& filename)
{
    PLUGIN_INFO("Loading octree from file: " << filename);
    std::ifstream file(filename, std::ios::in | std::ios::binary);
    if (!file.good())
        PLUGIN_THROW("Could not import octree from " + filename);

    file.read((char*)&_frameSize, sizeof(uint64_t));
    _frameData.resize(_frameSize);
    file.read((char*)_frameData.data(), _frameData.size() * sizeof(float));

    _offset = {_frameData[0], _frameData[1], _frameData[2]};
    _spacing = {_frameData[3], _frameData[4], _frameData[5]};
    _dimensions = {_frameData[6], _frameData[7], _frameData[8]};

    PLUGIN_INFO("Octree: dimensions=" << _dimensions << ", offset=" << _offset
                                      << ", spacing=" << _spacing);

    file.close();
}

AbstractSimulationHandlerPtr FieldsHandler::clone() const
{
    return std::make_shared<FieldsHandler>(*this);
}
} // namespace fields
} // namespace bioexplorer
