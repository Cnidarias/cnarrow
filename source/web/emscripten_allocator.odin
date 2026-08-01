package web

import "base:intrinsics"
import "base:runtime"
import "core:c"

foreign import libc "env.o"

@(default_calling_convention = "c")
foreign libc {
	cnarrow_aligned_alloc :: proc(size, alignment: c.size_t) -> rawptr ---
	cnarrow_aligned_free :: proc(ptr: rawptr) ---
}

emscripten_allocator :: proc "contextless" () -> runtime.Allocator {
	return {
		procedure = emscripten_allocator_proc,
	}
}

emscripten_alloc :: proc(size, alignment: int) -> []byte {
	ptr := cnarrow_aligned_alloc(c.size_t(size), c.size_t(alignment))
	if ptr == nil do return nil
	return ([^]byte)(ptr)[:size]
}

emscripten_free :: proc(ptr: rawptr) {
	if ptr == nil do return
	cnarrow_aligned_free(ptr)
}

emscripten_allocator_proc :: proc(
	allocator_data: rawptr,
	mode: runtime.Allocator_Mode,
	size, alignment: int,
	old_memory: rawptr,
	old_size: int,
	loc := #caller_location,
) -> ([]byte, runtime.Allocator_Error) {
	switch mode {
	case .Alloc:
		data := emscripten_alloc(size, alignment)
		if data == nil do return nil, .Out_Of_Memory
		return data, nil
	case .Alloc_Non_Zeroed:
		data := emscripten_alloc(size, alignment)
		if data == nil do return nil, .Out_Of_Memory
		return data, nil
	case .Resize, .Resize_Non_Zeroed:
		if old_memory == nil {
			data := emscripten_alloc(size, alignment)
			if data == nil do return nil, .Out_Of_Memory
			return data, nil
		}
		data := emscripten_alloc(size, alignment)
		if data == nil do return nil, .Out_Of_Memory
		copy_size := min(old_size, size)
		if copy_size > 0 do intrinsics.mem_copy(raw_data(data), old_memory, copy_size)
		if mode == .Resize && size > old_size {
			intrinsics.mem_zero(rawptr(uintptr(raw_data(data)) + uintptr(old_size)), size - old_size)
		}
		emscripten_free(old_memory)
		return data, nil
	case .Free:
		emscripten_free(old_memory)
		return nil, nil
	case .Query_Features:
		set := (^runtime.Allocator_Mode_Set)(old_memory)
		if set != nil {
			set^ = {.Alloc, .Alloc_Non_Zeroed, .Free, .Resize, .Resize_Non_Zeroed, .Query_Features}
		}
		return nil, nil
	case .Free_All, .Query_Info:
		return nil, .Mode_Not_Implemented
	}
	return nil, .Mode_Not_Implemented
}
