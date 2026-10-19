// Do not guess legacy encodings: accept UTF-8 and BOM-labelled UTF-16 only.
export function decodeSourceText(bytes: Uint8Array): string {
  const encoding = bytes[0] === 0xff && bytes[1] === 0xfe
    ? "utf-16le"
    : bytes[0] === 0xfe && bytes[1] === 0xff ? "utf-16be" : "utf-8";
  const text = new TextDecoder(encoding, { fatal: true }).decode(bytes);
  if (text.includes("\u0000")) throw new Error("Binary content is not text.");
  return text;
}

export function hasReadableSource(text: string): boolean {
  return text.trim().length > 0;
}
