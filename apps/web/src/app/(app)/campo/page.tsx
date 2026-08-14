"use client";

import { useState } from "react";
import { formatWorkOrderNumber } from "@gs/shared";

const STEPS = ["Agenda", "OS", "Campo", "Assinatura", "Anexo"] as const;

export default function CampoPage() {
  const [step, setStep] = useState<(typeof STEPS)[number]>("Agenda");
  const [offline, setOffline] = useState(true);
  const [accepted, setAccepted] = useState(false);
  const [sent, setSent] = useState(false);

  return (
    <div>
      <div className="mb-6">
        <h1 className="font-serif text-2xl text-navy">App do técnico</h1>
        <p className="mt-1 text-sm text-muted">
          Prévia do Flutter — registros do dia no aparelho e o certificado Excel
          anexado, caindo em Certificados no escritório.
        </p>
      </div>

      <div className="flex flex-col items-start gap-8 lg:flex-row">
        <div className="w-full max-w-[360px] overflow-hidden rounded-[2rem] border-[10px] border-navy bg-paper shadow-none">
          <div className="bg-navy px-4 py-3 text-paper">
            <div className="flex items-center justify-between text-[10px] uppercase tracking-widest text-brass-2">
              <span>GS Campo</span>
              <span>{offline ? "Sem sinal" : "Online"}</span>
            </div>
            <div className="mt-1 font-serif text-lg">
              {step === "Agenda" && "Minha agenda"}
              {step === "OS" && formatWorkOrderNumber(36, 2026)}
              {step === "Campo" && "Atendimento"}
              {step === "Assinatura" && "Assinatura"}
              {step === "Anexo" && "Certificado"}
            </div>
          </div>

          <div key={step} className="page-enter min-h-[520px] p-4 text-sm">
            {step === "Agenda" && (
              <div className="space-y-3">
                <button
                  type="button"
                  onClick={() => setStep("OS")}
                  className="w-full rounded-sm border border-line bg-white p-3 text-left"
                >
                  <div className="font-medium">GS 036/26 · 12/08</div>
                  <div className="text-muted">ALESAT/MG · Laje 1 · em atendimento</div>
                </button>
                <div className="rounded-sm border border-line bg-white p-3 text-left text-muted">
                  <div className="font-medium text-ink">GS 037/26 · hoje</div>
                  <div>TERMINAL BELÉM · Telemetria</div>
                </div>
                <div className="rounded-sm border border-line bg-white p-3 text-left text-muted">
                  <div className="font-medium text-ink">GS 038/26 · 20/08</div>
                  <div>ALESAT/MG · Carregamento</div>
                </div>
              </div>
            )}

            {step === "OS" && (
              <div className="space-y-3">
                <p className="text-muted">Betim/MG · SKID 01 · Descarregamento</p>
                <p>Equipe: Cleber (responsável), Felipe e André. OC 03900/26.</p>
                <div className="rounded-sm bg-navy/5 p-3 text-xs">
                  GPS da chegada: -19.9681, -44.1974
                </div>
                {!accepted ? (
                  <button
                    type="button"
                    onClick={() => {
                      setAccepted(true);
                      setStep("Campo");
                    }}
                    className="w-full rounded-sm bg-navy py-2 text-paper"
                  >
                    Aceitar e iniciar deslocamento
                  </button>
                ) : (
                  <button
                    type="button"
                    onClick={() => setStep("Campo")}
                    className="w-full rounded-sm bg-navy py-2 text-paper"
                  >
                    Continuar atendimento
                  </button>
                )}
              </div>
            )}

            {step === "Campo" && (
              <div className="space-y-3">
                <div className="grid grid-cols-4 gap-1 text-center text-[11px]">
                  {[
                    ["Entrada", "08:05"],
                    ["Almoço", "12:00"],
                    ["Retorno", "13:00"],
                    ["Saída", "17:40"],
                  ].map(([label, value]) => (
                    <div key={label} className="rounded-sm border border-line bg-white py-2">
                      <div className="text-[9px] uppercase tracking-wide text-muted">
                        {label}
                      </div>
                      <div className="font-medium">{value}</div>
                    </div>
                  ))}
                </div>
                <label className="block text-xs uppercase tracking-wide text-muted">
                  Descrição do serviço
                  <textarea
                    className="mt-1 w-full rounded-sm border border-line p-2 text-sm"
                    rows={3}
                    defaultValue="Montagem do padrão GS 001 e verificação de 4 pontos no Coriolis FT-01."
                  />
                </label>
                <div className="grid grid-cols-2 gap-2">
                  {["FT-01", "Padrão", "Preset", "Lacre"].map((label) => (
                    <div
                      key={label}
                      className="flex aspect-square items-end rounded-sm bg-navy p-2 text-xs text-paper"
                    >
                      Foto · {label}
                    </div>
                  ))}
                </div>
                <button
                  type="button"
                  onClick={() => setStep("Assinatura")}
                  className="w-full rounded-sm bg-navy py-2 text-paper"
                >
                  Coletar assinatura
                </button>
              </div>
            )}

            {step === "Assinatura" && (
              <div className="space-y-3">
                <p className="text-muted">Responsável da base · Renata Campos</p>
                <div className="flex h-28 items-center justify-center rounded-sm border border-dashed border-brass bg-white font-serif italic text-navy">
                  Renata Campos
                </div>
                <button
                  type="button"
                  onClick={() => setStep("Anexo")}
                  className="w-full rounded-sm bg-brass py-2 text-navy"
                >
                  Anexar certificado Excel
                </button>
              </div>
            )}

            {step === "Anexo" && (
              <div className="space-y-3">
                <div className="rounded-sm border border-dashed border-brass bg-white p-3">
                  <div className="text-[10px] uppercase tracking-widest text-brass">
                    Planilha GS
                  </div>
                  <div className="mt-1 font-medium text-navy">
                    CERTIFICADO 2303127.xlsx
                  </div>
                  <p className="mt-2 text-xs text-muted">
                    Feito no Excel · anexado na OS GS 036/26
                  </p>
                </div>
                <button
                  type="button"
                  onClick={() => setSent(true)}
                  className="w-full rounded-sm bg-brass py-2 text-navy"
                >
                  {offline
                    ? "Salvo no aparelho · sincroniza depois"
                    : sent
                      ? "No escritório · Certificados"
                      : "Enviar anexo ao escritório"}
                </button>
                {sent && !offline ? (
                  <p className="text-xs text-muted">
                    Abra Certificados no sistema web para baixar a planilha.
                  </p>
                ) : null}
              </div>
            )}
          </div>

          <div className="grid grid-cols-5 border-t border-line bg-white text-[10px] uppercase tracking-wide">
            {STEPS.map((item) => (
              <button
                key={item}
                type="button"
                onClick={() => setStep(item)}
                className={`py-3 ${step === item ? "text-navy" : "text-muted"}`}
              >
                {item}
              </button>
            ))}
          </div>
        </div>

        <div className="max-w-md space-y-4 text-sm">
          <label className="flex items-center gap-2">
            <input
              type="checkbox"
              checked={offline}
              onChange={(event) => setOffline(event.target.checked)}
              className="accent-navy"
            />
            Simular planta sem internet
          </label>
          <p className="text-muted">
            O certificado continua na planilha Excel. O app pega os registros da
            OS (horários, fotos, GPS, assinatura) e anexa o arquivo. Com o
            sistema web ligado, o anexo aparece em Certificados.
          </p>
        </div>
      </div>
    </div>
  );
}
