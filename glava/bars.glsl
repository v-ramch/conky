
/* Center line thickness (pixels) */
#define C_LINE 15
/* Width (in pixels) of each bar */
#define BAR_WIDTH 7
/* Width (in pixels) of each bar gap */
#define BAR_GAP 2
/* Outline color */
#define BAR_OUTLINE #dd5a17
/* Outline width (in pixels, set to 0 to disable outline drawing) */
#define BAR_OUTLINE_WIDTH 1
/* Amplify magnitude of the results each bar displays */
#define AMPLIFY 280
/* Whether the current settings use the alpha channel;#
   enabling this is required for alpha to function
   correctly on X11 with `"native"` transparency. */
#define USE_ALPHA 1
/* How strong the gradient changes */
#define GRADIENT_POWER -12
/* Bar color changes with height */
#define GRADIENT (d / GRADIENT_POWER + 2)
/* Bar color */
#define COLOR (#5eb5d1 * GRADIENT)
/* Direction that the bars are facing, 0 for inward, 1 for outward */
#define DIRECTION 1
/* Whether to switch left/right audio buffers */
#define INVERT 0
/* Whether to flip the output vertically */
#define FLIP 1
/* Whether to mirror output along `Y = X`, causing output to render on the left side of the window */
/* Use with `FLIP 1` to render on the right side */
#define MIRROR_YX 0

