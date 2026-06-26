#ifndef CONFIG_DEMO_H
#define CONFIG_DEMO_H

/* ===== A. Timing / mode ===== */
#define DEMO_TICK_HZ             (1000u)

/* ===== E. Limits / filters ===== */
#define DEMO_LED_MAX_DUTY        (1000u)

/* ===== Polarity =====
 * Placeholder only. On real hardware, identify with open-loop test:
 * positive command -> physical positive direction.
 */
#define DEMO_LED_OUTPUT_DIR      (+1)

#endif /* CONFIG_DEMO_H */
