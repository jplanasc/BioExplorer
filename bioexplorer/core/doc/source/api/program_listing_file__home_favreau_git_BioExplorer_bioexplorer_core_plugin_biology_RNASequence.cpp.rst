
.. _program_listing_file__home_favreau_git_BioExplorer_bioexplorer_core_plugin_biology_RNASequence.cpp:

Program Listing for File RNASequence.cpp
========================================

|exhale_lsh| :ref:`Return to documentation for file <file__home_favreau_git_BioExplorer_bioexplorer_core_plugin_biology_RNASequence.cpp>` (``/home/favreau/git/BioExplorer/bioexplorer/core/plugin/biology/RNASequence.cpp``)

.. |exhale_lsh| unicode:: U+021B0 .. UPWARDS ARROW WITH TIP LEFTWARDS

.. code-block:: cpp

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
   
   #include "RNASequence.h"
   
   #include <plugin/common/CommonTypes.h>
   #include <plugin/common/GeneralSettings.h>
   #include <plugin/common/Logs.h>
   #include <plugin/common/Utils.h>
   
   #include <brayns/engineapi/Material.h>
   #include <brayns/engineapi/Scene.h>
   
   namespace bioexplorer
   {
   namespace biology
   {
   using namespace common;
   
   struct Nucleotid
   {
       size_t index;
       std::string name;
       Vector3f color;
   };
   typedef std::map<char, Nucleotid> NucleotidMap;
   
   NucleotidMap nucleotidMap{{'A', {0, "Adenine", {0.f, 0.f, 1.f}}},
                             {'U', {1, "Uracile", {0.f, 1.f, 0.f}}},
                             {'G', {2, "Guanine", {1.f, 0.f, 0.f}}},
                             {'T', {3, "Thymine", {1.f, 0.f, 1.f}}},
                             {'C', {4, "Cytosine", {1.f, 1.f, 0.f}}}};
   
   RNASequence::RNASequence(Scene& scene, const RNASequenceDetails& details)
       : Node()
   {
       const auto& sequence = details.contents;
       const size_t nbElements = sequence.length();
   
       auto model = scene.createModel();
   
       size_t materialId = 0;
       for (const auto& nucleotid : nucleotidMap)
       {
           auto material =
               model->createMaterial(materialId, nucleotid.second.name);
           brayns::PropertyMap props;
           props.setProperty({MATERIAL_PROPERTY_SHADING_MODE,
                              static_cast<int>(MaterialShadingMode::basic)});
           props.setProperty({MATERIAL_PROPERTY_USER_PARAMETER, 1.0});
           props.setProperty(
               {MATERIAL_PROPERTY_CHAMELEON_MODE,
                static_cast<int>(
                    MaterialChameleonMode::undefined_chameleon_mode)});
           material->setDiffuseColor(nucleotid.second.color);
           material->updateProperties(props);
           ++materialId;
       }
   
       const size_t nbMaterials = materialId;
   
       PLUGIN_INFO("Sequence total length: " << nbElements);
       PLUGIN_INFO("Created " << nbMaterials << " materials");
   
       Vector3f U{details.range[0], details.range[1], nbElements};
       Vector3f V{details.range[0], details.range[1], nbElements};
   
       switch (details.shape)
       {
       case RNAShape::moebius:
           U = {2.f * M_PI, 4.f * M_PI, nbElements};
           V = {-0.4f, 0.4f, 1.f};
           break;
       case RNAShape::heart:
           U = {0.f, 2.f * M_PI, nbElements};
           V = {0.f, 1.f, 1.f};
           break;
       default:
           break;
       }
   
       const float uStep = (U.y - U.x) / U.z;
       const float vStep = (V.y - V.x) / V.z;
   
       size_t elementId = 0;
       for (float v(V.x); v < V.y; v += vStep)
       {
           for (float u(U.x); u < U.y; u += uStep)
           {
               Vector3f src;
               Vector3f dst;
               switch (details.shape)
               {
               case RNAShape::moebius:
               {
                   src = _moebius(details.assemblyParams[0], u, v);
                   dst = _moebius(details.assemblyParams[0], u + uStep, v);
                   break;
               }
               case RNAShape::torus:
               {
                   src = _torus(details.assemblyParams[0], u,
                                {details.params[0], details.params[1],
                                 details.params[2]});
                   dst = _torus(details.assemblyParams[0], u + uStep,
                                {details.params[0], details.params[1],
                                 details.params[2]});
                   break;
               }
               case RNAShape::star:
               {
                   src = _star(details.assemblyParams[0], u);
                   dst = _star(details.assemblyParams[0], u + uStep);
                   break;
               }
               case RNAShape::spring:
               {
                   src = _spring(details.assemblyParams[0], u);
                   dst = _spring(details.assemblyParams[0], u + uStep);
                   break;
               }
               case RNAShape::trefoilKnot:
               {
                   src = _trefoilKnot(details.assemblyParams[0], u,
                                      {details.params[0], details.params[1],
                                       details.params[2]});
                   dst = _trefoilKnot(details.assemblyParams[0], u + uStep,
                                      {details.params[0], details.params[1],
                                       details.params[2]});
                   break;
               }
               case RNAShape::heart:
               {
                   src = _heart(details.assemblyParams[0], u);
                   dst = _heart(details.assemblyParams[0], u + uStep);
                   break;
               }
               case RNAShape::thing:
               {
                   src = _thing(details.assemblyParams[0], u,
                                {details.params[0], details.params[1],
                                 details.params[2]});
                   dst = _thing(details.assemblyParams[0], u + uStep,
                                {details.params[0], details.params[1],
                                 details.params[2]});
                   break;
               }
               default:
                   PLUGIN_THROW("Undefined shape");
                   break;
               }
   
               const char letter = sequence[elementId];
               if (nucleotidMap.find(letter) != nucleotidMap.end())
               {
                   const auto& codon = nucleotidMap[letter];
                   const auto materialId = codon.index;
                   const auto radius = details.assemblyParams[1];
                   const Vector3f position{details.position[0],
                                           details.position[1],
                                           details.position[2]};
                   model->addCylinder(materialId,
                                      {position + src, position + dst, radius});
                   if (elementId == 0)
                       model->addSphere(materialId, {position + src, radius});
                   if (elementId == nbElements - 1)
                       model->addSphere(materialId, {position + dst, radius});
               }
               if (elementId == nbElements)
                   break;
               ++elementId;
           }
       }
   
       // Metadata
       ModelMetadata metadata;
       metadata[METADATA_ASSEMBLY] = details.assemblyName;
       metadata["RNA sequence"] = sequence;
       _modelDescriptor =
           std::make_shared<ModelDescriptor>(std::move(model), details.name,
                                             metadata);
       if (_modelDescriptor &&
           !GeneralSettings::getInstance()->getModelVisibilityOnCreation())
           _modelDescriptor->setVisible(false);
   }
   
   Vector3f RNASequence::_trefoilKnot(const float radius, const float t,
                                      const Vector3f& params)
   {
       return {radius * (sin(t) + 2.f * sin(params.x * t)),
               radius * (cos(t) - 2.f * cos(params.y * t)),
               radius * (-sin(params.z * t))};
   }
   
   Vector3f RNASequence::_torus(const float radius, const float t,
                                const Vector3f& params)
   {
       return {radius * (cos(t) + params.x * cos(params.y * t) * cos(t)),
               radius * (sin(t) + params.x * cos(params.y * t) * sin(t)),
               radius * params.x * sin(params.y * t)};
   }
   
   Vector3f RNASequence::_star(const float radius, const float t)
   {
       return {radius * (2.f * sin(3.f * t) * cos(t)),
               radius * (2.f * sin(3.f * t) * sin(t)), radius * sin(3.f * t)};
   }
   
   Vector3f RNASequence::_spring(const float radius, const float t)
   {
       return {radius * cos(t), radius * sin(t), radius * cos(t)};
   }
   
   Vector3f RNASequence::_heart(const float radius, const float u)
   {
       return {radius * 4.f * pow(sin(u), 3.f),
               radius * 0.25f *
                   (13.f * cos(u) - 5.f * cos(2.f * u) - 2.f * cos(3.f * u) -
                    cos(4.f * u)),
               0.f};
   }
   
   Vector3f RNASequence::_thing(const float radius, const float t,
                                const Vector3f& params)
   {
       return {radius * (sin(t) + params.x * sin(params.y * t)),
               radius * (cos(t) - params.x * cos(params.y * t)),
               radius * (-sin(params.z * t))};
   }
   
   Vector3f RNASequence::_moebius(const float radius, const float u, const float v)
   {
       return {4.f * radius * (cos(u) + v * cos(u / 2.f) * cos(u)),
               4.f * radius * (sin(u) + v * cos(u / 2.f) * sin(u)),
               8.f * radius * (v * sin(u / 2.f))};
   }
   } // namespace biology
   } // namespace bioexplorer
