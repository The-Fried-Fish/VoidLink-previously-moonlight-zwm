// When enabled, rendering occurs on the main application thread.
// This can make responding to UI events during redraw simpler
// to manage because UI calls usually need to occur on the main thread.
// When disabled, rendering occurs on a background thread, allowing
// the UI to respond more quickly in some cases because events can
// process asynchronously from potentially CPU-intensive rendering code.
#define RENDER_ON_MAIN_THREAD 0

// When enabled, the drawable's size updates automatically whenever
// the view resizes. When disabled, you can update the drawable's
// size explicitly outside the view class.
#define AUTOMATICALLY_RESIZE 1

