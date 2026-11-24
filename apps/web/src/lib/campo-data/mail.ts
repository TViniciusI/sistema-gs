import { gatePost } from "./gate";

export async function sendCampoOsMail(input: {
  osId: string;
  osNumber: string;
  subject: string;
  body: string;
  to?: string[];
  cc?: string[];
  replyTo?: string;
}): Promise<{ ok: boolean; error?: string; to?: string }> {
  const subject = String(input.subject || "").trim();
  const body = String(input.body || "").trim();
  if (!subject || !body) {
    return { ok: false, error: "Informe assunto e texto do e-mail." };
  }

  const payload = await gatePost(
    {
      action: "sendmail",
      osId: input.osId,
      osNumber: input.osNumber,
      subject,
      body,
      replyTo: input.replyTo || "",
      to: input.to || [],
      cc: input.cc || [],
      files: [],
    },
    { timeoutMs: 90_000 },
  );

  if (!payload) return { ok: false, error: "Sem resposta do gate." };
  if (payload.ok !== true) {
    return {
      ok: false,
      error: String(payload.error || "Falha ao enviar e-mail."),
    };
  }
  return { ok: true, to: String(payload.to || "") };
}
