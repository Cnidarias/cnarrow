mergeInto(LibraryManager.library, {
  rand_bytes: function (pointer, length) {
    const target = HEAPU8.subarray(pointer >>> 0, (pointer + length) >>> 0);
    if (globalThis.crypto && typeof globalThis.crypto.getRandomValues === 'function') {
      globalThis.crypto.getRandomValues(target);
      return;
    }
    for (let i = 0; i < target.length; i += 1) target[i] = (Math.random() * 256) | 0;
  },
  sin: function (value) {
    return Math.sin(value);
  },
  write: function (_fd, _pointer, length) {
    return length;
  },
});
