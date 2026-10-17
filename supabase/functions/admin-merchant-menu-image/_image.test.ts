import { assert, assertEquals, assertRejects } from "jsr:@std/assert@1.0.14";
// @ts-types="./_vendor/index.d.ts"
import { MagickFormat, MagickImage } from "./_vendor/index.js";
import { normalizeMenuImage } from "./_image.ts";

// Tiny, synthetic Pillow-generated fixtures. No user images or binary assets.
const fixtures: Record<string, string> = {
  "valid.jpg":
    "/9j/4AAQSkZJRgABAQAAAQABAAD/4QA+RXhpZgAATU0AKgAAAAgAAgEOAAIAAAAQAAAAJgESAAMAAAABAAYAAAAAAABTRUNSRVQtTUVUQURBVEEA/9sAQwAIBgYHBgUIBwcHCQkICgwUDQwLCwwZEhMPFB0aHx4dGhwcICQuJyAiLCMcHCg3KSwwMTQ0NB8nOT04MjwuMzQy/9sAQwEJCQkMCwwYDQ0YMiEcITIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIy/8AAEQgAeACgAwEiAAIRAQMRAf/EAB8AAAEFAQEBAQEBAAAAAAAAAAABAgMEBQYHCAkKC//EALUQAAIBAwMCBAMFBQQEAAABfQECAwAEEQUSITFBBhNRYQcicRQygZGhCCNCscEVUtHwJDNicoIJChYXGBkaJSYnKCkqNDU2Nzg5OkNERUZHSElKU1RVVldYWVpjZGVmZ2hpanN0dXZ3eHl6g4SFhoeIiYqSk5SVlpeYmZqio6Slpqeoqaqys7S1tre4ubrCw8TFxsfIycrS09TV1tfY2drh4uPk5ebn6Onq8fLz9PX29/j5+v/EAB8BAAMBAQEBAQEBAQEAAAAAAAABAgMEBQYHCAkKC//EALURAAIBAgQEAwQHBQQEAAECdwABAgMRBAUhMQYSQVEHYXETIjKBCBRCkaGxwQkjM1LwFWJy0QoWJDThJfEXGBkaJicoKSo1Njc4OTpDREVGR0hJSlNUVVZXWFlaY2RlZmdoaWpzdHV2d3h5eoKDhIWGh4iJipKTlJWWl5iZmqKjpKWmp6ipqrKztLW2t7i5usLDxMXGx8jJytLT1NXW19jZ2uLj5OXm5+jp6vLz9PX29/j5+v/aAAwDAQACEQMRAD8A62iiivyg+0CiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigD/9k=",
  "progressive.jpg":
    "/9j/4AAQSkZJRgABAQAAAQABAAD/2wBDAAgGBgcGBQgHBwcJCQgKDBQNDAsLDBkSEw8UHRofHh0aHBwgJC4nICIsIxwcKDcpLDAxNDQ0Hyc5PTgyPC4zNDL/2wBDAQkJCQwLDBgNDRgyIRwhMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjL/wgARCAB4AKADASIAAhEBAxEB/8QAFQABAQAAAAAAAAAAAAAAAAAAAAX/xAAWAQEBAQAAAAAAAAAAAAAAAAAABQb/2gAMAwEAAhADEAAAAawydoAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAD//EABQQAQAAAAAAAAAAAAAAAAAAAID/2gAIAQEAAQUCFn//xAAUEQEAAAAAAAAAAAAAAAAAAABg/9oACAEDAQE/ASH/xAAUEQEAAAAAAAAAAAAAAAAAAABg/9oACAECAQE/ASH/xAAUEAEAAAAAAAAAAAAAAAAAAACA/9oACAEBAAY/AhZ//8QAFBABAAAAAAAAAAAAAAAAAAAAgP/aAAgBAQABPyEWf//aAAwDAQACAAMAAAAQ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++/8QAFBEBAAAAAAAAAAAAAAAAAAAAYP/aAAgBAwEBPxAh/8QAFBEBAAAAAAAAAAAAAAAAAAAAYP/aAAgBAgEBPxAh/8QAFBABAAAAAAAAAAAAAAAAAAAAgP/aAAgBAQABPxAWf//Z",
  "valid.png":
    "iVBORw0KGgoAAAANSUhEUgAAAKAAAAB4CAIAAAD6wG44AAAAF3RFWHRDb21tZW50AFNFQ1JFVC1NRVRBREFUQTI34OAAAAEsSURBVHic7dEBCQAgAMAwtX8Nc2oKEc6W4PB59iBs/Q7gLYPjDI4zOM7gOIPjDI4zOM7gOIPjDI4zOM7gOIPjDI4zOM7gOIPjDI4zOM7gOIPjDI4zOM7gOIPjDI4zOM7gOIPjDI4zOM7gOIPjDI4zOM7gOIPjDI4zOM7gOIPjDI4zOM7gOIPjDI4zOM7gOIPjDI4zOM7gOIPjDI4zOM7gOIPjDI4zOM7gOIPjDI4zOM7gOIPjDI4zOM7gOIPjDI4zOM7gOIPjDI4zOM7gOIPjDI4zOM7gOIPjDI4zOM7gOIPjDI4zOM7gOIPjDI4zOM7gOIPjDI4zOM7gOIPjDI4zOM7gOIPjDI4zOM7gOIPjDI4zOM7gOIPjDI4zOM7gOIPjDI4zOM7gOIPjDI67lDMClIDgkNwAAAAASUVORK5CYII=",
  "transparent.png":
    "iVBORw0KGgoAAAANSUhEUgAAAKAAAAB4CAYAAAB1ovlvAAABS0lEQVR4nO3SMQEAIAzAsIFW/FsAGT1IFPToujNnILLrAP5mQFIGJGVAUgYkZUBSBiRlQFIGJGVAUgYkZUBSBiRlQFIGJGVAUgYkZUBSBiRlQFIGJGVAUgYkZUBSBiRlQFIGJGVAUgYkZUBSBiRlQFIGJGVAUgYkZUBSBiRlQFIGJGVAUgYkZUBSBiRlQFIGJGVAUgYkZUBSBiRlQFIGJGVAUgYkZUBSBiRlQFIGJGVAUgYkZUBSBiRlQFIGJGVAUgYkZUBSBiRlQFIGJGVAUgYkZUBSBiRlQFIGJGVAUgYkZUBSBiRlQFIGJGVAUgYkZUBSBiRlQFIGJGVAUgYkZUBSBiRlQFIGJGVAUgYkZUBSBiRlQFIGJGVAUgYkZUBSBiRlQFIGJGVAUgYkZUBSBiRlQFIGJGVAUgYkZUBSBiRlQFIGJGVAUgYk9QDNQwJTBaQXDQAAAABJRU5ErkJggg==",
  "valid.webp":
    "UklGRsIAAABXRUJQVlA4WAoAAAAIAAAAnwAAdwAAVlA4IGYAAADQBwCdASqgAHgAPm02mUmkIyKhIGgAgA2JaW7hdUlwH4AAAO6HVUmyYh1VJsmIdVSbJiHVUmyYh1VJsmIdVSbJiHVUmyYWAAD+/sRt//+7zft5v283/DR//89M15g/poAAAAAAAABFWElGNgAAAE1NACoAAAAIAAIBDgACAAAAEAAAACYBEgADAAAAAQAGAAAAAAAAU0VDUkVULU1FVEFEQVRBAA==",
  "lossless.webp": "UklGRiIAAABXRUJQVlA4TBYAAAAvn8AdAAfQ0v5H/wMAivT/v0T0P/UK",
  "animated.png":
    "iVBORw0KGgoAAAANSUhEUgAAAKAAAAB4CAIAAAD6wG44AAAACGFjVEwAAAACAAAAAPONk3AAAAAaZmNUTAAAAAAAAACgAAAAeAAAAAAAAAAAAAEACgAAQSbTDwAAASxJREFUeJzt0QEJACAAwDC1fw1zagoRzpbg8Hn2IGz9DuAtg+MMjjM4zuA4g+MMjjM4zuA4g+MMjjM4zuA4g+MMjjM4zuA4g+MMjjM4zuA4g+MMjjM4zuA4g+MMjjM4zuA4g+MMjjM4zuA4g+MMjjM4zuA4g+MMjjM4zuA4g+MMjjM4zuA4g+MMjjM4zuA4g+MMjjM4zuA4g+MMjjM4zuA4g+MMjjM4zuA4g+MMjjM4zuA4g+MMjjM4zuA4g+MMjjM4zuA4g+MMjjM4zuA4g+MMjjM4zuA4g+MMjjM4zuA4g+MMjjM4zuA4g+MMjjM4zuA4g+MMjjM4zuA4g+MMjjM4zuA4g+MMjjM4zuA4g+MMjjM4zuA4g+MMjjM4zuA4g+MMjjM4zuA4g+MMjruUMwKUgOCQ3AAAABpmY1RMAAAAAQAAAKAAAAB4AAAAAAAAAAAAAQAKAADaVTnbAAABMGZkQVQAAAACeJzt0QEJACAQwMDX/p01hQjjLsFga+YMXft3AG8ZHGdwnMFxBscZHGdwnMFxBscZHGdwnMFxBscZHGdwnMFxBscZHGdwnMFxBscZHGdwnMFxBscZHGdwnMFxBscZHGdwnMFxBscZHGdwnMFxBscZHGdwnMFxBscZHGdwnMFxBscZHGdwnMFxBscZHGdwnMFxBscZHGdwnMFxBscZHGdwnMFxBscZHGdwnMFxBscZHGdwnMFxBscZHGdwnMFxBscZHGdwnMFxBscZHGdwnMFxBscZHGdwnMFxBscZHGdwnMFxBscZHGdwnMFxBscZHGdwnMFxBscZHGdwnMFxBscZHGdwnMFxBscZHGdwnMFxBscZHGdwnMFxBscZHGdwnMFxBscZHGdw3AU4qAHvqpzscQAAAABJRU5ErkJggg==",
  "animated.webp":
    "UklGRlwBAABXRUJQVlA4WAoAAAACAAAAnwAAdwAAQU5JTQYAAAAAAAAAAABBTk1GmAAAAAAAAAAAAJ8AAHcAAGQAAAJWUDgggAAAAHAKAJ0BKqAAeAA+bTaaSaQjIqEgaACADYlpbt/wL0C8AfoB+/8p7TQH4AAm5hyzEUjFWooam8sXw+g0+yBKDdAvh9Bp9kCUG6BfD6DT7IEoN0C+H0Gn2QJQbnQAAP7vIh//93m/bzft5v+Gj//56ZrzB/XYvv8MAXEjtRCMYAAAQU5NRpAAAAAAAAAAAACfAAB3AABkAAAAVlA4IHgAAABUCQCdASqgAHgAPm00k0mCBgAA2JaW7f8C9AvAH6ASPtNAAmJpyq8ECEUkkSF4j1st+wuP45BUvrZb9hcfxyCpfWy37C4/jkFS+tlv2Fx/HIKlIAD++SYv//kB//kB//kB//ID//iF3shmPw3pRMZ5wH+SgBYkAAA=",
  "gif-as-png.png":
    "R0lGODdhoAB4AIEAAP+lAAAAAAAAAAAAACwAAAAAoAB4AEAI3wABCBxIsKDBgwgTKlzIsKHDhxAjSpxIsaLFixgzatzIsaPHjyBDihxJsqTJkyhTqlzJsqXLlzBjypxJs6bNmzhz6tzJs6fPn0CDCh1KtKjRo0iTKl3KtKnTp1CjSp1KtarVq1izat3KtavXr2DDih1LtqzZs2jTql3Ltq3bt3Djyp1Lt67du3jz6t3Lt6/fv4ADCx5MuLDhw4gTK17MuLHjx5AjS55MubLly5gza97MubPnz6BDix5NurTp06hTq17NurXr17Bjy55Nu7bt27hz697Nu7fv38CDCx+uNSAAOw==",
  "boundary.png":
    "iVBORw0KGgoAAAANSUhEUgAAB9AAAAfQAQAAAACyQ/nUAAAB/UlEQVR4nO3BAQ0AAADCoPdPbQ43oAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAHg2qVkAAafGDaEAAAAASUVORK5CYII=",
};
function bytes(name: string): Uint8Array {
  return Uint8Array.from(atob(fixtures[name]), (value) => value.charCodeAt(0));
}
const mime: Record<string, string> = {
  jpg: "image/jpeg",
  png: "image/png",
  webp: "image/webp",
};
function contentType(name: string): string {
  return mime[name.split(".").at(-1)!];
}

Deno.test("normalizes JPEG, PNG and WebP to stripped, decoded WebP", async (test) => {
  for (
    const name of [
      "valid.jpg",
      "progressive.jpg",
      "valid.png",
      "transparent.png",
      "valid.webp",
      "lossless.webp",
    ]
  ) {
    await test.step(name, async () => {
      const output = await normalizeMenuImage(bytes(name), contentType(name));
      assert(output.length > 0 && output.length <= 4 * 1024 * 1024);
      const image = MagickImage.create(output);
      try {
        assertEquals(image.format, MagickFormat.WebP);
        assertEquals(image.profileNames, []);
        assertEquals(image.comment, null);
        const oriented = name === "valid.jpg" || name === "valid.webp";
        assertEquals(image.width, oriented ? 120 : 160);
        assertEquals(image.height, oriented ? 160 : 120);
        if (name === "transparent.png") assert(image.hasAlpha);
        assert(!new TextDecoder().decode(output).includes("SECRET-METADATA"));
      } finally {
        image.dispose();
      }
    });
  }
});

Deno.test("rejects MIME spoofing, unsupported formats and animated raster images", async (test) => {
  const cases: Array<[string, Uint8Array, string]> = [
    ["PNG labeled as JPEG", bytes("valid.png"), "image/jpeg"],
    ["JPEG labeled as PNG", bytes("valid.jpg"), "image/png"],
    ["WebP labeled as JPEG", bytes("valid.webp"), "image/jpeg"],
    ["unapproved MIME", bytes("valid.png"), "application/octet-stream"],
    [
      "SVG labeled as PNG",
      new TextEncoder().encode(
        '<svg xmlns="http://www.w3.org/2000/svg"><script>unsafe()</script></svg>',
      ),
      "image/png",
    ],
    ["GIF labeled as PNG", bytes("gif-as-png.png"), "image/png"],
    ["APNG", bytes("animated.png"), "image/png"],
    ["animated WebP", bytes("animated.webp"), "image/webp"],
  ];
  for (const [name, input, type] of cases) {
    await test.step(name, async () => {
      await assertRejects(() => normalizeMenuImage(input, type));
    });
  }
});

Deno.test("rejects malformed or truncated containers and trailing polyglot content", async (test) => {
  for (const name of ["valid.jpg", "valid.png", "valid.webp"]) {
    const original = bytes(name), type = contentType(name);
    await test.step(`truncated ${name}`, async () => {
      await assertRejects(() =>
        normalizeMenuImage(original.subarray(0, original.length >> 1), type)
      );
    });
    await test.step(`trailing ${name}`, async () => {
      const input = new Uint8Array(original.length + 5);
      input.set(original);
      input.set([1, 2, 3, 4, 5], original.length);
      await assertRejects(() => normalizeMenuImage(input, type));
    });
  }
  await test.step("JPEG polyglot with a second EOI", async () => {
    const original = bytes("valid.jpg"),
      suffix = new TextEncoder().encode("<script>unsafe()</script>");
    const input = new Uint8Array(original.length + suffix.length + 2);
    input.set(original);
    input.set(suffix, original.length);
    input.set([0xff, 0xd9], input.length - 2);
    await assertRejects(() => normalizeMenuImage(input, "image/jpeg"));
  });
});

Deno.test("fully decodes compressed content instead of accepting a valid header", async (test) => {
  await test.step("corrupt PNG pixel stream with unchanged valid container", async () => {
    const input = bytes("valid.png"), view = new DataView(input.buffer);
    let offset = 8;
    while (offset + 12 < input.length) {
      const length = view.getUint32(offset);
      if (
        new TextDecoder().decode(input.subarray(offset + 4, offset + 8)) ===
          "IDAT"
      ) {
        input[offset + 8] ^= 0xff;
        break;
      }
      offset += length + 12;
    }
    await assertRejects(() => normalizeMenuImage(input, "image/png"));
  });
  await test.step("JPEG header with missing scan data", async () => {
    const original = bytes("valid.jpg");
    let start = 0;
    for (let i = 2; i < original.length - 4; i++) {
      if (original[i] === 0xff && original[i + 1] === 0xda) {
        start = i + 2 + original[i + 2] * 256 + original[i + 3];
        break;
      }
    }
    assert(start > 0);
    const input = new Uint8Array(start + 3);
    input.set(original.subarray(0, start));
    input.set([0, 0xff, 0xd9], start);
    await assertRejects(() => normalizeMenuImage(input, "image/jpeg"));
  });
  await test.step("corrupt WebP pixel stream with valid dimensions", async () => {
    const input = bytes("valid.webp"), view = new DataView(input.buffer);
    let offset = 12;
    while (offset + 8 < input.length) {
      const length = view.getUint32(offset + 4, true);
      if (
        new TextDecoder().decode(input.subarray(offset, offset + 4)) === "VP8 "
      ) {
        input.fill(0, offset + 18, offset + 8 + length);
        break;
      }
      offset += length + 8 + (length & 1);
    }
    await assertRejects(() => normalizeMenuImage(input, "image/webp"));
  });
});

Deno.test("rejects oversized bytes and decompression-bomb dimensions before decoding", async (test) => {
  await test.step("empty body", async () => {
    await assertRejects(() =>
      normalizeMenuImage(new Uint8Array(), "image/png")
    );
  });
  await test.step("more than four MiB", async () => {
    await assertRejects(() =>
      normalizeMenuImage(new Uint8Array(4 * 1024 * 1024 + 1), "image/png")
    );
  });
  for (const [width, height] of [[0, 120], [65535, 120], [2048, 2048]]) {
    await test.step(`PNG dimensions ${width}x${height}`, async () => {
      const input = bytes("valid.png"), view = new DataView(input.buffer);
      view.setUint32(16, width);
      view.setUint32(20, height);
      await assertRejects(
        () => normalizeMenuImage(input, "image/png"),
        Error,
        "image_dimensions_exceeded",
      );
    });
  }
});

Deno.test("concurrent calls share initialization and keep image state isolated", async () => {
  const results = await Promise.all(
    ["valid.jpg", "valid.png", "valid.webp"].map((name) =>
      normalizeMenuImage(bytes(name), contentType(name))
    ),
  );
  assertEquals(results.length, 3);
  for (const result of results) {
    const image = MagickImage.create(result);
    try {
      assertEquals(image.format, MagickFormat.WebP);
      assertEquals(image.profileNames, []);
    } finally {
      image.dispose();
    }
  }
});

Deno.test("accepts the four megapixel boundary and limits output to 1024 pixels", async () => {
  const output = await normalizeMenuImage(bytes("boundary.png"), "image/png");
  const image = MagickImage.create(output);
  try {
    assertEquals(image.width, 1024);
    assertEquals(image.height, 1024);
    assertEquals(image.format, MagickFormat.WebP);
    assertEquals(image.profileNames, []);
  } finally {
    image.dispose();
  }
});
