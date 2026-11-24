"use client";

import { useState, useTransition } from "react";
import { sendOsMailAction } from "@/app/(app)/os/actions";

export function OsMailForm({
  osId,
  osNumber,
  defaultTo,
  defaultBody,
}: {
  osId: string;
  osNumber: string;
  defaultTo?: string;
  defaultBody: string;
}) {
  const [pending, startTransition] = useTransition();
  const [error, setError] = useState<string | null>(null);
  const [ok, setOk] = useState<string | null>(null);
  const [to, setTo] = useState(defaultTo || "");
  const [cc, setCc] = useState("");
  const [subject, setSubject] = useState(
    `OS GS ${osNumber} — documentos GS Soluções`,
  );
  const [body, setBody] = useState(defaultBody);

  function submit() {
    setError(null);
    setOk(null);
    startTransition(async () => {
      const result = await sendOsMailAction({
        osId,
        subject,
        body,
        to,
        cc,
      });
      if (!result.ok) {
        setError(result.error || "Falha no envio.");
        return;
      }
      setOk(result.to ? `Enviado para ${result.to}` : "E-mail enviado.");
    });
  }

  return (
    <div className="space-y-3">
      <label className="block text-sm">
        <span className="text-[11px] font-semibold uppercase tracking-wide text-navy/45">
          Para
        </span>
        <input
          value={to}
          onChange={(e) => setTo(e.target.value)}
          placeholder="deixe vazio = e-mails administrativos da planilha"
          className="mt-1.5 w-full rounded-xl border border-navy/15 bg-white px-3 py-2.5 text-sm text-navy"
        />
      </label>
      <label className="block text-sm">
        <span className="text-[11px] font-semibold uppercase tracking-wide text-navy/45">
          Cc
        </span>
        <input
          value={cc}
          onChange={(e) => setCc(e.target.value)}
          className="mt-1.5 w-full rounded-xl border border-navy/15 bg-white px-3 py-2.5 text-sm text-navy"
        />
      </label>
      <label className="block text-sm">
        <span className="text-[11px] font-semibold uppercase tracking-wide text-navy/45">
          Assunto
        </span>
        <input
          value={subject}
          onChange={(e) => setSubject(e.target.value)}
          className="mt-1.5 w-full rounded-xl border border-navy/15 bg-white px-3 py-2.5 text-sm text-navy"
        />
      </label>
      <label className="block text-sm">
        <span className="text-[11px] font-semibold uppercase tracking-wide text-navy/45">
          Mensagem (links Drive)
        </span>
        <textarea
          value={body}
          onChange={(e) => setBody(e.target.value)}
          rows={8}
          className="mt-1.5 w-full rounded-xl border border-navy/15 bg-white px-3 py-2.5 text-sm text-navy"
        />
      </label>
      <button
        type="button"
        disabled={pending}
        onClick={submit}
        className="rounded-xl bg-navy px-4 py-2.5 text-sm font-semibold text-paper hover:bg-navy-2 disabled:opacity-60"
      >
        {pending ? "Enviando…" : "Enviar e-mail"}
      </button>
      {error ? <p className="text-sm text-red-700">{error}</p> : null}
      {ok ? <p className="text-sm text-ok">{ok}</p> : null}
    </div>
  );
}
