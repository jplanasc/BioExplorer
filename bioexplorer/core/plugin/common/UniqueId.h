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

#include <stdint.h>

namespace bioexplorer
{
namespace common
{
/**
 * @brief The UniqueID class provides a way to get a unique identifier accross
 * the application
 *
 */
class UniqueId
{
protected:
    static uint32_t nextId;

public:
    /**
     * @brief Construct a new UniqueId object
     *
     */
    UniqueId();

    /**
     * @brief Get a unique identifier
     *
     * @return uint32_t
     */
    static uint32_t get();
};
} // namespace common
} // namespace bioexplorer
