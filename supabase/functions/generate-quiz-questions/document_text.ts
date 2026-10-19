import JSZip from "npm:jszip@3.10.1";

const maxExtractedTextBytes = 8 * 1024 * 1024;

export async function decodeOfficeDocument(
  bytes: Uint8Array,
  mimeType: string,
): Promise<string> {
  if (bytes.length < 4 || bytes[0] !== 0x50 || bytes[1] !== 0x4b) {
    throw new Error("The office document is not a valid ZIP package.");
  }

  const archive = await JSZip.loadAsync(bytes);
  const names = Object.keys(archive.files);
  const xmlNames = mimeType ===
      "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
    ? names.filter((name) =>
      /^word\/(?:document|header\d+|footer\d+)\.xml$/i.test(name)
    )
    : names
      .filter((name) => /^ppt\/slides\/slide\d+\.xml$/i.test(name))
      .sort((left, right) => slideNumber(left) - slideNumber(right));

  if (xmlNames.length === 0) {
    throw new Error("The office document contains no readable content.");
  }

  const sections: string[] = [];
  let extractedBytes = 0;
  for (const name of xmlNames) {
    const file = archive.files[name];
    if (!file || file.dir) continue;
    const xml = await file.async("string");
    const text = extractXmlText(xml);
    if (text.length === 0) continue;
    extractedBytes += new TextEncoder().encode(text).length;
    if (extractedBytes > maxExtractedTextBytes) {
      throw new Error("The office document contains too much extracted text.");
    }
    sections.push(text);
  }

  const result = sections.join("\n\n").trim();
  if (!result) {
    throw new Error("The office document is empty or contains no readable text.");
  }
  return result;
}

function slideNumber(name: string): number {
  const match = /slide(\d+)\.xml$/i.exec(name);
  return match ? Number(match[1]) : 0;
}

function extractXmlText(xml: string): string {
  const text = [...xml.matchAll(/<(?:w:t|a:t)[^>]*>([\s\S]*?)<\/(?:w:t|a:t)>/gi)]
    .map((match) => decodeXmlEntities(match[1]))
    .join(" ");
  return text.replace(/\s+/g, " ").trim();
}

function decodeXmlEntities(value: string): string {
  return value
    .replace(/&lt;/g, "<")
    .replace(/&gt;/g, ">")
    .replace(/&quot;/g, '"')
    .replace(/&apos;/g, "'")
    .replace(/&#(\d+);/g, (_, code) => String.fromCodePoint(Number(code)))
    .replace(/&#x([0-9a-f]+);/gi, (_, code) =>
      String.fromCodePoint(parseInt(code, 16))
    )
    .replace(/&amp;/g, "&");
}
