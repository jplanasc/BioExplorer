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

#include "Params.h"
#include "json.hpp"

#if !defined(DOXYGEN_SHOULD_SKIP_THIS)

#ifndef BRAYNS_DEBUG_JSON_ENABLED
#define FROM_JSON(PARAM, JSON, NAME) \
    PARAM.NAME = JSON[#NAME].get<decltype(PARAM.NAME)>()
#else
#define FROM_JSON(PARAM, JSON, NAME)                                         \
    try                                                                      \
    {                                                                        \
        PARAM.NAME = JSON[#NAME].get<decltype(PARAM.NAME)>();                \
    }                                                                        \
    catch (...)                                                              \
    {                                                                        \
        PLUGIN_ERROR("JSON parsing error for attribute '" << #NAME << "'!"); \
        throw;                                                               \
    }
#endif
#define TO_JSON(PARAM, JSON, NAME) JSON[#NAME] = PARAM.NAME

std::string to_json(const Response &param)
{
    try
    {
        nlohmann::json js;
        TO_JSON(param, js, status);
        TO_JSON(param, js, contents);
        return js.dump();
    }
    catch (...)
    {
        return "";
    }
    return "";
}

std::string to_json(const SceneInformationDetails &param)
{
    try
    {
        nlohmann::json js;
        TO_JSON(param, js, nbModels);
        TO_JSON(param, js, nbMaterials);
        TO_JSON(param, js, nbSpheres);
        TO_JSON(param, js, nbCylinders);
        TO_JSON(param, js, nbCones);
        TO_JSON(param, js, nbVertices);
        TO_JSON(param, js, nbIndices);
        TO_JSON(param, js, nbNormals);
        TO_JSON(param, js, nbColors);
        return js.dump();
    }
    catch (...)
    {
        return "";
    }
    return "";
}

bool from_json(GeneralSettingsDetails &param, const std::string &payload)
{
    try
    {
        auto js = nlohmann::json::parse(payload);
        FROM_JSON(param, js, modelVisibilityOnCreation);
        FROM_JSON(param, js, offFolder);
        FROM_JSON(param, js, loggingEnabled);
    }
    catch (...)
    {
        return false;
    }
    return true;
}

bool from_json(AssemblyDetails &param, const std::string &payload)
{
    try
    {
        auto js = nlohmann::json::parse(payload);
        FROM_JSON(param, js, name);
        FROM_JSON(param, js, position);
        FROM_JSON(param, js, rotation);
        FROM_JSON(param, js, clippingPlanes);
    }
    catch (...)
    {
        return false;
    }
    return true;
}

std::string to_json(const AssemblyDetails &payload)
{
    try
    {
        nlohmann::json js;

        TO_JSON(payload, js, name);
        TO_JSON(payload, js, position);
        TO_JSON(payload, js, rotation);
        TO_JSON(payload, js, clippingPlanes);
        return js.dump();
    }
    catch (...)
    {
        return "";
    }
    return "";
}

bool from_json(AssemblyTransformationsDetails &param,
               const std::string &payload)
{
    try
    {
        auto js = nlohmann::json::parse(payload);
        FROM_JSON(param, js, assemblyName);
        FROM_JSON(param, js, name);
        FROM_JSON(param, js, transformations);
    }
    catch (...)
    {
        return false;
    }
    return true;
}

bool from_json(ColorSchemeDetails &param, const std::string &payload)
{
    try
    {
        auto js = nlohmann::json::parse(payload);
        FROM_JSON(param, js, assemblyName);
        FROM_JSON(param, js, name);
        FROM_JSON(param, js, colorScheme);
        FROM_JSON(param, js, palette);
        FROM_JSON(param, js, chainIds);
    }
    catch (...)
    {
        return false;
    }
    return true;
}

bool from_json(AminoAcidSequenceAsStringDetails &param,
               const std::string &payload)
{
    try
    {
        auto js = nlohmann::json::parse(payload);
        FROM_JSON(param, js, assemblyName);
        FROM_JSON(param, js, name);
        FROM_JSON(param, js, sequence);
    }
    catch (...)
    {
        return false;
    }
    return true;
}

bool from_json(AminoAcidSequenceAsRangesDetails &param,
               const std::string &payload)
{
    try
    {
        auto js = nlohmann::json::parse(payload);
        FROM_JSON(param, js, assemblyName);
        FROM_JSON(param, js, name);
        FROM_JSON(param, js, ranges);
    }
    catch (...)
    {
        return false;
    }
    return true;
}

bool from_json(AminoAcidInformationDetails &param, const std::string &payload)
{
    try
    {
        auto js = nlohmann::json::parse(payload);
        FROM_JSON(param, js, assemblyName);
        FROM_JSON(param, js, name);
    }
    catch (...)
    {
        return false;
    }
    return true;
}

bool from_json(AminoAcidDetails &param, const std::string &payload)
{
    try
    {
        auto js = nlohmann::json::parse(payload);
        FROM_JSON(param, js, assemblyName);
        FROM_JSON(param, js, name);
        FROM_JSON(param, js, index);
        FROM_JSON(param, js, aminoAcidShortName);
        FROM_JSON(param, js, chainIds);
    }
    catch (...)
    {
        return false;
    }
    return true;
}

bool from_json(RNASequenceDetails &param, const std::string &payload)
{
    try
    {
        auto js = nlohmann::json::parse(payload);
        FROM_JSON(param, js, assemblyName);
        FROM_JSON(param, js, name);
        FROM_JSON(param, js, contents);
        FROM_JSON(param, js, proteinContents);
        FROM_JSON(param, js, shape);
        FROM_JSON(param, js, assemblyParams);
        FROM_JSON(param, js, range);
        FROM_JSON(param, js, params);
        FROM_JSON(param, js, position);
        FROM_JSON(param, js, rotation);
    }
    catch (...)
    {
        return false;
    }
    return true;
}

bool from_json(ParametricMembraneDetails &param, const std::string &payload)
{
    try
    {
        auto js = nlohmann::json::parse(payload);
        FROM_JSON(param, js, assemblyName);
        FROM_JSON(param, js, name);
        FROM_JSON(param, js, content1);
        FROM_JSON(param, js, content2);
        FROM_JSON(param, js, content3);
        FROM_JSON(param, js, content4);
        FROM_JSON(param, js, shape);
        FROM_JSON(param, js, assemblyParams);
        FROM_JSON(param, js, atomRadiusMultiplier);
        FROM_JSON(param, js, loadBonds);
        FROM_JSON(param, js, loadNonPolymerChemicals);
        FROM_JSON(param, js, representation);
        FROM_JSON(param, js, chainIds);
        FROM_JSON(param, js, recenter);
        FROM_JSON(param, js, occurrences);
        FROM_JSON(param, js, randomSeed);
        FROM_JSON(param, js, positionRandomizationType);
        FROM_JSON(param, js, rotation);
    }
    catch (...)
    {
        return false;
    }
    return true;
}

bool from_json(ProteinDetails &param, const std::string &payload)
{
    try
    {
        auto js = nlohmann::json::parse(payload);
        FROM_JSON(param, js, assemblyName);
        FROM_JSON(param, js, name);
        FROM_JSON(param, js, contents);
        FROM_JSON(param, js, shape);
        FROM_JSON(param, js, assemblyParams);
        FROM_JSON(param, js, atomRadiusMultiplier);
        FROM_JSON(param, js, loadBonds);
        FROM_JSON(param, js, loadNonPolymerChemicals);
        FROM_JSON(param, js, loadHydrogen);
        FROM_JSON(param, js, representation);
        FROM_JSON(param, js, chainIds);
        FROM_JSON(param, js, recenter);
        FROM_JSON(param, js, occurrences);
        FROM_JSON(param, js, allowedOccurrences);
        FROM_JSON(param, js, randomSeed);
        FROM_JSON(param, js, positionRandomizationType);
        FROM_JSON(param, js, position);
        FROM_JSON(param, js, rotation);
        FROM_JSON(param, js, constraints);
    }
    catch (...)
    {
        return false;
    }
    return true;
}

std::string to_json(const ProteinDetails &payload)
{
    try
    {
        nlohmann::json js;

        TO_JSON(payload, js, assemblyName);
        TO_JSON(payload, js, name);
        TO_JSON(payload, js, contents);
        TO_JSON(payload, js, shape);
        TO_JSON(payload, js, assemblyParams);
        TO_JSON(payload, js, atomRadiusMultiplier);
        TO_JSON(payload, js, loadBonds);
        TO_JSON(payload, js, loadNonPolymerChemicals);
        TO_JSON(payload, js, loadHydrogen);
        TO_JSON(payload, js, representation);
        TO_JSON(payload, js, chainIds);
        TO_JSON(payload, js, recenter);
        TO_JSON(payload, js, occurrences);
        TO_JSON(payload, js, allowedOccurrences);
        TO_JSON(payload, js, randomSeed);
        TO_JSON(payload, js, positionRandomizationType);
        TO_JSON(payload, js, position);
        TO_JSON(payload, js, rotation);
        return js.dump();
    }
    catch (...)
    {
        return "";
    }
    return "";
}

bool from_json(SugarsDetails &param, const std::string &payload)
{
    try
    {
        auto js = nlohmann::json::parse(payload);
        FROM_JSON(param, js, assemblyName);
        FROM_JSON(param, js, name);
        FROM_JSON(param, js, contents);
        FROM_JSON(param, js, proteinName);
        FROM_JSON(param, js, atomRadiusMultiplier);
        FROM_JSON(param, js, loadBonds);
        FROM_JSON(param, js, representation);
        FROM_JSON(param, js, recenter);
        FROM_JSON(param, js, chainIds);
        FROM_JSON(param, js, siteIndices);
        FROM_JSON(param, js, rotation);
        FROM_JSON(param, js, assemblyParams);
    }
    catch (...)
    {
        return false;
    }
    return true;
}

bool from_json(MeshBasedMembraneDetails &param, const std::string &payload)
{
    try
    {
        auto js = nlohmann::json::parse(payload);
        FROM_JSON(param, js, assemblyName);
        FROM_JSON(param, js, name);
        FROM_JSON(param, js, meshContents);
        FROM_JSON(param, js, proteinContents1);
        FROM_JSON(param, js, proteinContents2);
        FROM_JSON(param, js, proteinContents3);
        FROM_JSON(param, js, proteinContents4);
        FROM_JSON(param, js, recenter);
        FROM_JSON(param, js, density);
        FROM_JSON(param, js, surfaceFixedOffset);
        FROM_JSON(param, js, surfaceVariableOffset);
        FROM_JSON(param, js, assemblyParams);
        FROM_JSON(param, js, atomRadiusMultiplier);
        FROM_JSON(param, js, representation);
        FROM_JSON(param, js, randomSeed);
        FROM_JSON(param, js, position);
        FROM_JSON(param, js, rotation);
        FROM_JSON(param, js, scale);
    }
    catch (...)
    {
        return false;
    }
    return true;
}

bool from_json(AddGridDetails &param, const std::string &payload)
{
    try
    {
        auto js = nlohmann::json::parse(payload);
        FROM_JSON(param, js, minValue);
        FROM_JSON(param, js, maxValue);
        FROM_JSON(param, js, steps);
        FROM_JSON(param, js, radius);
        FROM_JSON(param, js, planeOpacity);
        FROM_JSON(param, js, showAxis);
        FROM_JSON(param, js, showPlanes);
        FROM_JSON(param, js, showFullGrid);
        FROM_JSON(param, js, useColors);
        FROM_JSON(param, js, position);
    }
    catch (...)
    {
        return false;
    }
    return true;
}

bool from_json(AddSphereDetails &param, const std::string &payload)
{
    try
    {
        auto js = nlohmann::json::parse(payload);
        FROM_JSON(param, js, name);
        FROM_JSON(param, js, position);
        FROM_JSON(param, js, radius);
        FROM_JSON(param, js, color);
    }
    catch (...)
    {
        return false;
    }
    return true;
}

bool from_json(ModelIdDetails &param, const std::string &payload)
{
    try
    {
        auto js = nlohmann::json::parse(payload);
        FROM_JSON(param, js, modelId);
    }
    catch (...)
    {
        return false;
    }
    return true;
}

bool from_json(MaterialsDetails &param, const std::string &payload)
{
    try
    {
        auto js = nlohmann::json::parse(payload);
        FROM_JSON(param, js, modelIds);
        FROM_JSON(param, js, materialIds);
        FROM_JSON(param, js, diffuseColors);
        FROM_JSON(param, js, specularColors);
        FROM_JSON(param, js, specularExponents);
        FROM_JSON(param, js, reflectionIndices);
        FROM_JSON(param, js, opacities);
        FROM_JSON(param, js, refractionIndices);
        FROM_JSON(param, js, emissions);
        FROM_JSON(param, js, glossinesses);
        FROM_JSON(param, js, shadingModes);
        FROM_JSON(param, js, userParameters);
        FROM_JSON(param, js, chameleonModes);
    }
    catch (...)
    {
        return false;
    }
    return true;
}

std::string to_json(const IdsDetails &param)
{
    try
    {
        nlohmann::json js;
        TO_JSON(param, js, ids);
        return js.dump();
    }
    catch (...)
    {
        return "";
    }
    return "";
}

std::string to_json(const ModelNameDetails &param)
{
    try
    {
        nlohmann::json js;
        TO_JSON(param, js, name);
        return js.dump();
    }
    catch (...)
    {
        return "";
    }
    return "";
}

// Fields
bool from_json(BuildFieldsDetails &param, const std::string &payload)
{
    try
    {
        auto js = nlohmann::json::parse(payload);
        FROM_JSON(param, js, voxelSize);
        FROM_JSON(param, js, density);
    }
    catch (...)
    {
        return false;
    }
    return true;
}

bool from_json(FileAccessDetails &param, const std::string &payload)
{
    try
    {
        auto js = nlohmann::json::parse(payload);
        FROM_JSON(param, js, filename);
        FROM_JSON(param, js, lowBounds);
        FROM_JSON(param, js, highBounds);
        FROM_JSON(param, js, fileFormat);
    }
    catch (...)
    {
        return false;
    }
    return true;
}

bool from_json(DatabaseAccessDetails &param, const std::string &payload)
{
    try
    {
        auto js = nlohmann::json::parse(payload);
        FROM_JSON(param, js, connectionString);
        FROM_JSON(param, js, schema);
        FROM_JSON(param, js, brickId);
        FROM_JSON(param, js, lowBounds);
        FROM_JSON(param, js, highBounds);
    }
    catch (...)
    {
        return false;
    }
    return true;
}

bool from_json(ModelIdFileAccessDetails &param, const std::string &payload)
{
    try
    {
        auto js = nlohmann::json::parse(payload);
        FROM_JSON(param, js, modelId);
        FROM_JSON(param, js, filename);
    }
    catch (...)
    {
        return false;
    }
    return true;
}

bool from_json(BuildPointCloudDetails &param, const std::string &payload)
{
    try
    {
        auto js = nlohmann::json::parse(payload);
        FROM_JSON(param, js, radius);
    }
    catch (...)
    {
        return false;
    }
    return true;
}

bool from_json(ModelsVisibilityDetails &param, const std::string &payload)
{
    try
    {
        auto js = nlohmann::json::parse(payload);
        FROM_JSON(param, js, visible);
    }
    catch (...)
    {
        return false;
    }
    return true;
}

bool from_json(ProteinInstanceTransformationDetails &param,
               const std::string &payload)
{
    try
    {
        auto js = nlohmann::json::parse(payload);
        FROM_JSON(param, js, assemblyName);
        FROM_JSON(param, js, name);
        FROM_JSON(param, js, instanceIndex);
        FROM_JSON(param, js, position);
        FROM_JSON(param, js, rotation);
    }
    catch (...)
    {
        return false;
    }
    return true;
}
#endif