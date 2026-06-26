#include "configDemo.h"
#include "pinMap.h"

int main(void)
{
    return (DEMO_LED_OUTPUT_DIR > 0) ? LED0_GPIO : 0;
}
