import { NextResponse } from "next/server";
import { getDemo } from "@/lib/demo/store";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type",
};

export async function OPTIONS() {
  return new NextResponse(null, { status: 204, headers: cors });
}

export async function GET(
  _request: Request,
  { params }: { params: Promise<{ id: string }> },
) {
  const { id } = await params;
  const certificate = getDemo().certificates.find(
    (item) => item.id === id || item.number === id,
  );

  if (!certificate?.fileBase64) {
    return NextResponse.json(
      { ok: false, error: "Anexo não encontrado." },
      { status: 404, headers: cors },
    );
  }

  const bytes = Buffer.from(certificate.fileBase64, "base64");
  const fileName = certificate.fileName ?? `certificado-${certificate.number}.xlsx`;
  return new NextResponse(bytes, {
    headers: {
      ...cors,
      "Content-Type": certificate.contentType ?? "application/octet-stream",
      "Content-Disposition": `attachment; filename="${fileName}"`,
    },
  });
}
