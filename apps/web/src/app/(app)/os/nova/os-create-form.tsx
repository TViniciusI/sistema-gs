"use client";

import { useActionState, useMemo, useState, useTransition } from "react";
import { Button } from "@/components/ui";
import { createCampoOs, type CreateOsState } from "../actions";

export type OsClientOption = {
  id: string;
  name: string;
  cnpj: string;
  city: string;
  state: string;
  baseName: string;
  baseCargo: string;
  baseEmail: string;
  basePhone: string;
  sites: string[];
  systems: { id: string; systemType: string; installLocation: string }[];
};

export type OsTechOption = {
  email: string;
  login: string;
  name: string;
  cargo: string;
  funcao: string;
};

const SERVICE_KINDS = [
  { value: "manutencao", label: "Manutenção" },
  { value: "calibracao", label: "Calibração" },
  { value: "configuracao", label: "Configuração" },
  { value: "visita", label: "Visita técnica" },
  { value: "outro", label: "Outro / descrever" },
] as const;

const initialState: CreateOsState = {};

export function OsCreateForm({
  clients,
  technicians,
}: {
  clients: OsClientOption[];
  technicians: OsTechOption[];
}) {
  const [state, formAction] = useActionState(createCampoOs, initialState);
  const [pending, startTransition] = useTransition();
  const [clientId, setClientId] = useState("");
  const [number, setNumber] = useState("");
  const [startsAt, setStartsAt] = useState(() =>
    new Date().toISOString().slice(0, 10),
  );
  const [cnpj, setCnpj] = useState("");
  const [client, setClient] = useState("");
  const [site, setSite] = useState("");
  const [systemType, setSystemType] = useState("");
  const [serviceKind, setServiceKind] = useState("calibracao");
  const [serviceOther, setServiceOther] = useState("");
  const [baseName, setBaseName] = useState("");
  const [baseCargo, setBaseCargo] = useState("");
  const [baseEmail, setBaseEmail] = useState("");
  const [basePhone, setBasePhone] = useState("");
  const [selected, setSelected] = useState<string[]>([]);

  const selectedClient = useMemo(
    () => clients.find((c) => c.id === clientId) ?? null,
    [clients, clientId],
  );

  function applyClient(id: string) {
    setClientId(id);
    const found = clients.find((c) => c.id === id);
    if (!found) return;
    setClient(found.name);
    setCnpj(found.cnpj);
    setBaseName(found.baseName);
    setBaseCargo(found.baseCargo);
    setBaseEmail(found.baseEmail);
    setBasePhone(found.basePhone);
    const place = [found.city, found.state].filter(Boolean).join(" / ");
    setSite(found.sites[0] || place);
    const firstSystem = found.systems[0];
    if (firstSystem?.systemType) setSystemType(firstSystem.systemType);
  }

  function toggleTech(email: string) {
    setSelected((prev) =>
      prev.includes(email)
        ? prev.filter((item) => item !== email)
        : [...prev, email],
    );
  }

  function submit(intent: "draft" | "dispatch") {
    const form = document.getElementById("os-create-form") as HTMLFormElement | null;
    if (!form) return;
    const data = new FormData(form);
    data.set("intent", intent);
    startTransition(() => {
      formAction(data);
    });
  }

  return (
    <form id="os-create-form" className="space-y-6" action={formAction}>
      {state.error ? (
        <div
          role="alert"
          className="rounded-2xl border border-danger/30 bg-danger/5 px-4 py-3 text-sm text-danger"
        >
          {state.error}
        </div>
      ) : null}

      <section className="rounded-3xl border border-navy/10 bg-white p-5 md:p-6">
        <p className="text-[11px] font-semibold uppercase tracking-[0.22em] text-brass">
          Identificação
        </p>
        <h2 className="mt-1 font-serif text-xl text-navy">Dados da OS</h2>
        <div className="mt-5 grid gap-4 md:grid-cols-2">
          <label className="block">
            <span className="mb-1 block text-xs font-medium uppercase tracking-wide text-muted">
              Número da OS
            </span>
            <input
              name="number"
              required
              value={number}
              onChange={(e) => setNumber(e.target.value)}
              placeholder="Ex.: 1842"
              className="w-full rounded-xl border border-navy/15 bg-white px-3 py-2.5 text-sm outline-none focus:border-brass"
            />
          </label>
          <label className="block">
            <span className="mb-1 block text-xs font-medium uppercase tracking-wide text-muted">
              Início do serviço
            </span>
            <input
              name="startsAt"
              type="date"
              required
              value={startsAt}
              onChange={(e) => setStartsAt(e.target.value)}
              className="w-full rounded-xl border border-navy/15 bg-white px-3 py-2.5 text-sm outline-none focus:border-brass"
            />
          </label>
        </div>
      </section>

      <section className="rounded-3xl border border-navy/10 bg-white p-5 md:p-6">
        <p className="text-[11px] font-semibold uppercase tracking-[0.22em] text-brass">
          Cliente
        </p>
        <h2 className="mt-1 font-serif text-xl text-navy">Contratante</h2>
        <div className="mt-5 grid gap-4 md:grid-cols-2">
          <label className="block md:col-span-2">
            <span className="mb-1 block text-xs font-medium uppercase tracking-wide text-muted">
              Cliente cadastrado
            </span>
            <select
              value={clientId}
              onChange={(e) => applyClient(e.target.value)}
              className="w-full rounded-xl border border-navy/15 bg-white px-3 py-2.5 text-sm outline-none focus:border-brass"
            >
              <option value="">Selecionar da planilha…</option>
              {clients.map((item) => (
                <option key={item.id} value={item.id}>
                  {item.name}
                  {item.cnpj ? ` · ${item.cnpj}` : ""}
                </option>
              ))}
            </select>
          </label>
          <label className="block">
            <span className="mb-1 block text-xs font-medium uppercase tracking-wide text-muted">
              CNPJ
            </span>
            <input
              name="cnpj"
              required
              value={cnpj}
              onChange={(e) => setCnpj(e.target.value)}
              className="w-full rounded-xl border border-navy/15 bg-white px-3 py-2.5 text-sm outline-none focus:border-brass"
            />
          </label>
          <label className="block">
            <span className="mb-1 block text-xs font-medium uppercase tracking-wide text-muted">
              Contratante
            </span>
            <input
              name="client"
              required
              value={client}
              onChange={(e) => setClient(e.target.value)}
              className="w-full rounded-xl border border-navy/15 bg-white px-3 py-2.5 text-sm outline-none focus:border-brass"
            />
          </label>
          <label className="block md:col-span-2">
            <span className="mb-1 block text-xs font-medium uppercase tracking-wide text-muted">
              Local do serviço
            </span>
            <input
              name="site"
              value={site}
              onChange={(e) => setSite(e.target.value)}
              list="os-sites"
              className="w-full rounded-xl border border-navy/15 bg-white px-3 py-2.5 text-sm outline-none focus:border-brass"
            />
            <datalist id="os-sites">
              {(selectedClient?.sites ?? []).map((item) => (
                <option key={item} value={item} />
              ))}
            </datalist>
          </label>
          <label className="block md:col-span-2">
            <span className="mb-1 block text-xs font-medium uppercase tracking-wide text-muted">
              Tipo de sistema
            </span>
            <input
              name="systemType"
              value={systemType}
              onChange={(e) => setSystemType(e.target.value)}
              list="os-systems"
              className="w-full rounded-xl border border-navy/15 bg-white px-3 py-2.5 text-sm outline-none focus:border-brass"
            />
            <datalist id="os-systems">
              {(selectedClient?.systems ?? []).map((item) => (
                <option
                  key={item.id}
                  value={item.systemType || item.installLocation}
                />
              ))}
            </datalist>
          </label>
        </div>
      </section>

      <section className="rounded-3xl border border-navy/10 bg-white p-5 md:p-6">
        <p className="text-[11px] font-semibold uppercase tracking-[0.22em] text-brass">
          Serviço
        </p>
        <h2 className="mt-1 font-serif text-xl text-navy">Tipo contratado</h2>
        <input type="hidden" name="serviceKind" value={serviceKind} />
        <div className="mt-4 flex flex-wrap gap-2">
          {SERVICE_KINDS.map((kind) => {
            const active = serviceKind === kind.value;
            return (
              <button
                key={kind.value}
                type="button"
                onClick={() => setServiceKind(kind.value)}
                className={[
                  "rounded-full border px-3.5 py-2 text-sm font-medium transition",
                  active
                    ? "border-brass bg-navy text-brass"
                    : "border-navy/15 bg-white text-navy hover:border-brass/45",
                ].join(" ")}
              >
                {kind.label}
              </button>
            );
          })}
        </div>
        {serviceKind === "outro" ? (
          <label className="mt-4 block">
            <span className="mb-1 block text-xs font-medium uppercase tracking-wide text-muted">
              Descreva o serviço
            </span>
            <input
              name="serviceOther"
              value={serviceOther}
              onChange={(e) => setServiceOther(e.target.value)}
              required
              className="w-full rounded-xl border border-navy/15 bg-white px-3 py-2.5 text-sm outline-none focus:border-brass"
            />
          </label>
        ) : (
          <input type="hidden" name="serviceOther" value="" />
        )}
      </section>

      <section className="rounded-3xl border border-navy/10 bg-white p-5 md:p-6">
        <p className="text-[11px] font-semibold uppercase tracking-[0.22em] text-brass">
          Base
        </p>
        <h2 className="mt-1 font-serif text-xl text-navy">Responsável no local</h2>
        <div className="mt-5 grid gap-4 md:grid-cols-2">
          <label className="block">
            <span className="mb-1 block text-xs font-medium uppercase tracking-wide text-muted">
              Nome
            </span>
            <input
              name="baseName"
              value={baseName}
              onChange={(e) => setBaseName(e.target.value)}
              className="w-full rounded-xl border border-navy/15 bg-white px-3 py-2.5 text-sm outline-none focus:border-brass"
            />
          </label>
          <label className="block">
            <span className="mb-1 block text-xs font-medium uppercase tracking-wide text-muted">
              Cargo
            </span>
            <input
              name="baseCargo"
              value={baseCargo}
              onChange={(e) => setBaseCargo(e.target.value)}
              className="w-full rounded-xl border border-navy/15 bg-white px-3 py-2.5 text-sm outline-none focus:border-brass"
            />
          </label>
          <label className="block">
            <span className="mb-1 block text-xs font-medium uppercase tracking-wide text-muted">
              E-mail
            </span>
            <input
              name="baseEmail"
              type="email"
              value={baseEmail}
              onChange={(e) => setBaseEmail(e.target.value)}
              className="w-full rounded-xl border border-navy/15 bg-white px-3 py-2.5 text-sm outline-none focus:border-brass"
            />
          </label>
          <label className="block">
            <span className="mb-1 block text-xs font-medium uppercase tracking-wide text-muted">
              Telefone
            </span>
            <input
              name="basePhone"
              value={basePhone}
              onChange={(e) => setBasePhone(e.target.value)}
              className="w-full rounded-xl border border-navy/15 bg-white px-3 py-2.5 text-sm outline-none focus:border-brass"
            />
          </label>
        </div>
      </section>

      <section className="rounded-3xl border border-navy/10 bg-white p-5 md:p-6">
        <p className="text-[11px] font-semibold uppercase tracking-[0.22em] text-brass">
          Equipe
        </p>
        <h2 className="mt-1 font-serif text-xl text-navy">Técnicos de campo</h2>
        <p className="mt-1 text-sm text-navy/50">
          O primeiro marcado fica como responsável principal da OS.
        </p>
        <input
          type="hidden"
          name="technicianCargo"
          value="Técnico em Instrumentação Industrial"
        />
        <div className="mt-4 space-y-2">
          {technicians.length === 0 ? (
            <p className="rounded-2xl border border-dashed border-navy/15 px-4 py-6 text-sm text-muted">
              Nenhum técnico aprovado na planilha.
            </p>
          ) : (
            technicians.map((tech) => {
              const email = (tech.email || `${tech.login}@gssolucoestec.com.br`)
                .trim()
                .toLowerCase();
              const checked = selected.includes(email);
              return (
                <div
                  key={email}
                  className={[
                    "rounded-2xl border px-4 py-3",
                    checked
                      ? "border-brass/50 bg-paper/80"
                      : "border-navy/10 bg-white",
                  ].join(" ")}
                >
                  <label className="flex cursor-pointer items-start gap-3">
                    <input
                      type="checkbox"
                      checked={checked}
                      onChange={() => toggleTech(email)}
                      className="mt-1 accent-navy"
                    />
                    <span className="min-w-0 flex-1">
                      <span className="block text-sm font-semibold text-navy">
                        {tech.name}
                      </span>
                      <span className="block text-xs text-navy/50">
                        {email}
                        {tech.cargo ? ` · ${tech.cargo}` : ""}
                      </span>
                    </span>
                  </label>
                  {checked ? (
                    <div className="mt-3 grid gap-3 border-t border-navy/8 pt-3 md:grid-cols-2">
                      <input type="hidden" name="techEmail" value={email} />
                      <input type="hidden" name="techName" value={tech.name} />
                      <label className="block">
                        <span className="mb-1 block text-[11px] font-medium uppercase tracking-wide text-muted">
                          Função no RDO
                        </span>
                        <input
                          name={`funcao_${email}`}
                          defaultValue={
                            tech.funcao ||
                            (selected[0] === email
                              ? "Responsável técnico"
                              : "Apoio técnico")
                          }
                          className="w-full rounded-xl border border-navy/15 bg-white px-3 py-2 text-sm outline-none focus:border-brass"
                        />
                      </label>
                      <label className="block">
                        <span className="mb-1 block text-[11px] font-medium uppercase tracking-wide text-muted">
                          Cargo
                        </span>
                        <input
                          name={`cargo_${email}`}
                          defaultValue={
                            tech.cargo ||
                            "Técnico em Instrumentação Industrial"
                          }
                          className="w-full rounded-xl border border-navy/15 bg-white px-3 py-2 text-sm outline-none focus:border-brass"
                        />
                      </label>
                    </div>
                  ) : null}
                </div>
              );
            })
          )}
        </div>
      </section>

      <div className="flex flex-wrap items-center justify-end gap-3 pb-4">
        <Button
          type="button"
          variant="ghost"
          disabled={pending}
          onClick={() => submit("draft")}
        >
          {pending ? "Salvando…" : "Só salvar rascunho"}
        </Button>
        <Button
          type="button"
          disabled={pending}
          onClick={() => submit("dispatch")}
        >
          {pending ? "Enviando…" : "Salvar e enviar à agenda"}
        </Button>
      </div>
    </form>
  );
}
