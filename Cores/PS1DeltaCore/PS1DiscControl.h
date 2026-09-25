#pragma once

#include "../PCSXReARMed/deps/libretro-common/include/libretro.h"

static inline bool PS1SwapDisc(const struct retro_disk_control_ext_callback *control, unsigned index)
{
    if (!control || index >= control->get_num_images()) return false;
    unsigned previous = control->get_image_index();
    if (index == previous) return true;
    if (!control->set_eject_state(true)) return false;
    if (!control->set_image_index(index)) {
        control->set_image_index(previous);
        control->set_eject_state(false);
        return false;
    }
    return control->set_eject_state(false);
}
