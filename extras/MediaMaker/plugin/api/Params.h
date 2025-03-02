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

#pragma once

#include <plugin/common/Types.h>

#include <limits>
#include <string>
#include <vector>

namespace bioexplorer
{
namespace mediamaker
{
// Response
struct Response
{
    bool status{true};
    std::string contents;
};
std::string to_json(const Response &param);

// Movies and frames
struct CameraDefinition
{
    std::vector<double> origin;
    std::vector<double> direction;
    std::vector<double> up;
    double apertureRadius{0.0};
    double focusDistance{1e6};
    double interpupillaryDistance{0.0};
};
bool from_json(CameraDefinition &param, const std::string &payload);
std::string to_json(const CameraDefinition &param);

struct ExportFramesToDisk
{
    std::string path;
    std::string baseName;
    std::string format;
    uint16_t quality{100};
    uint16_t spp{0};
    uint16_t startFrame{0};
    uint16_t endFrame{std::numeric_limits<uint16_t>::max()};
    bool exportIntermediateFrames{false};
    std::vector<uint64_t> animationInformation;
    std::vector<double> cameraInformation;
    FrameBufferMode frameBufferMode{FrameBufferMode::color};
};
bool from_json(ExportFramesToDisk &param, const std::string &payload);

struct FrameExportProgress
{
    float progress;
    bool done;
};
std::string to_json(const FrameExportProgress &exportProgress);

} // namespace mediamaker
} // namespace bioexplorer
