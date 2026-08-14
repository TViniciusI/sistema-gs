import { NextResponse } from "next/server";
import { ingestFieldCertificate } from "@/lib/demo/queries";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type",
};

export async function OPTIONS() {
  return new NextResponse(null, { status: 204, headers: cors });
}

export async function POST(request: Request) {
  const body = (await request.json()) as {
    number?: string;
    workOrderId?: string;
    instrument?: string;
    tag?: string;
    principle?: string;
    standard?: string;
    signer?: string;
    issuedAt?: string;
    fileName?: string;
    contentType?: string;
    fileBase64?: string;
    pdfBase64?: string;
  };

  if (!body.number || !body.workOrderId || !body.issuedAt) {
    return NextResponse.json(
      { ok: false, error: "number, workOrderId e issuedAt são obrigatórios." },
      { status: 400, headers: cors },
    );
  }

  const result = ingestFieldCertificate({
    number: body.number,
    workOrderId: body.workOrderId,
    instrument: body.instrument ?? "",
    tag: body.tag ?? "",
    principle: body.principle ?? "",
    standard: body.standard ?? "",
    signer: body.signer ?? "Cleber Barbosa Guimarães",
    issuedAt: body.issuedAt,
    fileName: body.fileName,
    contentType: body.contentType,
    fileBase64: body.fileBase64 ?? body.pdfBase64,
  });

  if (!result.ok) {
    return NextResponse.json(result, { status: 404, headers: cors });
  }

  return NextResponse.json(
    { ok: true, id: result.certificate.id, number: result.certificate.number },
    { status: 201, headers: cors },
  );
}
