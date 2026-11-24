"use client";

import { useRouter } from "next/navigation";
import { useState, useTransition } from "react";
import { uploadStaffDocAction } from "@/app/(app)/equipe/docs-actions";

const KINDS = [
  { value: "holerite", label: "Holerite" },
  { value: "foto", label: "Foto" },
  { value: "registro", label: "Registro / prontuário" },
  { value: "contrato", label: "Contrato" },
  { value: "aso", label: "ASO / exame" },
  { value: "anexo", label: "Outro anexo" },
];

function fileToBase64(file: File): Promise<string> {
  return new Promise((resolve, reject) => {
    const reader = new FileReader();
    reader.onerror = () => reject(new Error("Falha ao ler o arquivo."));
    reader.onload = () => {
      const result = String(reader.result || "");
      const comma = result.indexOf(",");
      resolve(comma >= 0 ? result.slice(comma + 1) : result);
    };
    reader.readAsDataURL(file);
  });
}

export function StaffDocUploadForm({
  staffEmail,
  staffName,
}: {
  staffEmail: string;
  staffName: string;
}) {
  const router = useRouter();
  const [pending, startTransition] = useTransition();
  const [kind, setKind] = useState("holerite");
  const [requiresSignature, setRequiresSignature] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [ok, setOk] = useState(false);

  return (
    <form
      className="rounded-3xl border border-navy/10 bg-white p-5 md:p-6"
      onSubmit={(e) => {
        e.preventDefault();
        const form = e.currentTarget;
        const fileInput = form.elements.namedItem("file") as HTMLInputElement;
        const file = fileInput?.files?.[0];
        if (!file) {
          setError("Escolha um PDF ou foto.");
          return;
        }
        if (file.size > 12 * 1024 * 1024) {
          setError("Arquivo acima de 12 MB.");
          return;
        }
        setError(null);
        setOk(false);
        startTransition(async () => {
          try {
            const data = await fileToBase64(file);
            const result = await uploadStaffDocAction({
              staffEmail,
              name: file.name,
              kind,
              requiresSignature,
              mime: file.type || undefined,
              data,
            });
            if (!result.ok) {
              setError(result.error || "Falha ao anexar.");
              return;
            }
            setOk(true);
            form.reset();
            setKind("holerite");
            setRequiresSignature(true);
            router.refresh();
          } catch (err) {
            setError(
              err instanceof Error ? err.message : "Falha ao ler o arquivo.",
            );
          }
        });
      }}
    >
      <p className="text-[11px] font-semibold uppercase tracking-[0.22em] text-brass">
        Anexar
      </p>
      <h2 className="mt-1 font-serif text-xl text-navy">
        Holerite, foto ou registro
      </h2>
      <p className="mt-1 text-sm text-navy/55">
        Para {staffName || staffEmail}. Se pedir assinatura, o funcionário vê em{" "}
        <strong className="font-medium text-navy">Documentos RH</strong> ao
        entrar com o login dele.
      </p>

      <div className="mt-4 grid gap-3 md:grid-cols-2">
        <label className="block text-sm md:col-span-2">
          <span className="text-[11px] uppercase tracking-wide text-navy/45">
            Arquivo (PDF ou imagem)
          </span>
          <input
            name="file"
            type="file"
            accept="application/pdf,image/*"
            required
            className="mt-1 w-full rounded-xl border border-navy/15 bg-paper px-3 py-2 text-sm"
          />
        </label>
        <label className="block text-sm">
          <span className="text-[11px] uppercase tracking-wide text-navy/45">
            Tipo
          </span>
          <select
            value={kind}
            onChange={(e) => {
              setKind(e.target.value);
              setRequiresSignature(
                e.target.value === "holerite" ||
                  e.target.value === "contrato" ||
                  e.target.value === "aso",
              );
            }}
            className="mt-1 w-full rounded-xl border border-navy/15 bg-white px-3 py-2 text-sm"
          >
            {KINDS.map((k) => (
              <option key={k.value} value={k.value}>
                {k.label}
              </option>
            ))}
          </select>
        </label>
        <label className="mt-6 flex items-center gap-2 text-sm text-navy">
          <input
            type="checkbox"
            checked={requiresSignature}
            onChange={(e) => setRequiresSignature(e.target.checked)}
          />
          Solicitar assinatura do funcionário
        </label>
      </div>

      <div className="mt-4 flex flex-wrap items-center gap-3">
        <button
          type="submit"
          disabled={pending || !staffEmail}
          className="rounded-xl bg-brass px-4 py-2.5 text-sm font-semibold text-navy hover:bg-brass-2 disabled:opacity-60"
        >
          {pending ? "Enviando…" : "Anexar documento"}
        </button>
        {error ? <p className="text-sm text-red-700">{error}</p> : null}
        {ok ? (
          <p className="text-sm text-ok">Anexado — já aparece na ficha.</p>
        ) : null}
      </div>
    </form>
  );
}
