#include "../PS1DiscControl.h"
#include <assert.h>

static unsigned current;
static bool ejected;
static bool failSelection;
static unsigned calls;

static bool set_eject(bool value) { ejected = value; calls++; return true; }
static unsigned get_current(void) { return current; }
static unsigned get_count(void) { return 4; }
static bool set_current(unsigned index)
{
    assert(ejected);
    calls++;
    if (failSelection && index == 2) return false;
    current = index;
    return true;
}

int main(void)
{
    struct retro_disk_control_ext_callback control = {
        .set_eject_state = set_eject,
        .get_image_index = get_current,
        .set_image_index = set_current,
        .get_num_images = get_count,
    };
    assert(PS1SwapDisc(&control, 3) && current == 3 && !ejected && calls == 3);
    assert(PS1SwapDisc(&control, 3) && calls == 3);
    assert(!PS1SwapDisc(&control, 4) && calls == 3);
    failSelection = true;
    assert(!PS1SwapDisc(&control, 2) && current == 3 && !ejected && calls == 7);
}
