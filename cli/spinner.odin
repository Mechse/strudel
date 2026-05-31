package main

import "core:fmt"
import "core:os"
import "core:sync"
import "core:thread"
import "core:time"

// A Spinner draws an animated "still working" indicator on a BACKGROUND thread,
// so the screen keeps moving even while the main thread is parked inside a
// blocking call (reading the LLM helper's output, running git, ...).
//
// `stop` is shared between two threads, so it is ONLY ever touched through
// sync.atomic_load / sync.atomic_store. `handle` is the OS thread we spawn.
Spinner :: struct {
	message: string,
	stop:    bool,
	handle:  ^thread.Thread,
}

@(private)
spinner_frames := [?]string{"⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"}

// Runs ON THE BACKGROUND THREAD. It receives the SAME Spinner the main thread
// owns, by pointer — that is why it can see the main thread flip `stop`.
//
// (If we passed the Spinner by value, the thread would animate a private copy
// whose `stop` never changes, and the loop would spin forever.)
@(private)
spinner_run :: proc(s: ^Spinner) {
	i := 0
	for !sync.atomic_load(&s.stop) {
		frame := spinner_frames[i %% len(spinner_frames)]
		// Redraw in place using explicit ANSI/CSI cursor commands instead of a bare
		// carriage return: \x1b[2K erases the whole line, \x1b[G moves the cursor to
		// column 1. Unlike the `\r` byte (which the tty driver can remap to a newline),
		// these are unambiguous cursor commands. We write to stderr so the spinner never
		// mixes into the commit message (which goes to stdout).
		fmt.eprintf("\x1b[2K\x1b[G%s %s", frame, s.message)
		i += 1
		time.sleep(100 * time.Millisecond)
	}
	fmt.eprint("\x1b[2K\x1b[G") // wipe the spinner line on the way out
}

// Begin animating. Safe to write `stop` plainly here: the thread does not exist yet.
spinner_start :: proc(s: ^Spinner, message: string) {
	s.message = message
	s.stop = false

	// Only animate on an interactive terminal. If stderr is piped or redirected to a
	// file, cursor escapes would just be garbage in the output, so print one static
	// line and skip the thread entirely (handle stays nil).
	if !os.is_tty(os.stderr) {
		fmt.eprintln(message)
		return
	}

	s.handle = thread.create_and_start_with_poly_data(s, spinner_run)
}

// Signal the thread to stop, wait for it to finish (and clear its line), then
// free the Thread allocation. Always pair every spinner_start with a spinner_stop.
spinner_stop :: proc(s: ^Spinner) {
	if s.handle == nil do return // non-tty path: no thread was started
	sync.atomic_store(&s.stop, true)
	thread.join(s.handle)
	thread.destroy(s.handle)
}
