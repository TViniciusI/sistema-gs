"use client";

import Link from "next/link";
import { useRouter } from "next/navigation";
import { useState, useTransition } from "react";
import { digitsOnly } from "@gs/shared";
import { CnpjField } from "@/components/cnpj-field";
import { useCnpjLookup } from "@/hooks/use-cnpj-lookup";
import { CLIENT_ASSEMBLY_KINDS } from "@/lib/campo-data/labels";
import { createClienteAction } from "@/app/(app)/clientes/actions";
import type { CampoClientSystemInput } from "@/lib/campo-data";

type SystemDraft = CampoClientSystemInput;

function emptySystem(): SystemDraft {
  return {
    systemType: "",
    installLocation: "",
    tag: "",
    kind: "preset",
    manufacturer: "",
    model: "",
    serialNumber: "",
    assemblyTag: "",
    meterCount: 0,
    pt100Count: 0,
    densimeterCount: 0,
  };
}

const inputClass =
  "mt-1 w-full rounded-xl border border-navy/15 bg-white px-3 py-2 text-navy outline-none focus:border-brass";

export function ClientCreateForm() {
  const router = useRouter();
  const { fetchCnpj, loading, error: cnpjError } = useCnpjLookup();
  const [pending, startTransition] = useTransition();
  const [error, setError] = useState<string | null>(null);
  const [cnpjMessage, setCnpjMessage] = useState<string | null>(null);
  const [duplicateId, setDuplicateId] = useState<string | null>(null);

  const [cnpj, setCnpj] = useState("");
  const [name, setName] = useState("");
  const [requester, setRequester] = useState("");
  const [sites, setSites] = useState("");
  const [cep, setCep] = useState("");
  const [street, setStreet] = useState("");
  const [number, setNumber] = useState("");
  const [complement, setComplement] = useState("");
  const [neighborhood, setNeighborhood] = useState("");
  const [city, setCity] = useState("");
  const [state, setState] = useState("");
  const [service, setService] = useState("Calibração");
  const [baseName, setBaseName] = useState("");
  const [baseCargo, setBaseCargo] = useState("");
  const [baseEmail, setBaseEmail] = useState("");
  const [basePhone, setBasePhone] = useState("");
  const [systems, setSystems] = useState<SystemDraft[]>([emptySystem()]);

  async function applyLookup() {
    setCnpjMessage(null);
    const result = await fetchCnpj(cnpj, true);
    if (!result) return;
    setName(result.razaoSocial || result.nomeFantasia || name);
    setCity(result.cidade || city);
    setState(result.estado || state);
    setStreet(result.street || street);
    setNumber(result.number || number);
    setComplement(result.complement || complement);
    setNeighborhood(result.neighborhood || neighborhood);
    setCep(result.cep || cep);
    if (result.telefone) setBasePhone(result.telefone);
    if (result.email) setBaseEmail(result.email);
    setCnpjMessage(
      result.source === "brasilapi"
        ? `Preenchido pela Receita Federal (${result.razaoSocial}).`
        : `Preenchido com cadastro local (${result.razaoSocial}).`,
    );
  }

  function updateSystem(index: number, patch: Partial<SystemDraft>) {
    setSystems((prev) =>
      prev.map((item, i) => (i === index ? { ...item, ...patch } : item)),
    );
  }

  return (
    <form
      className="space-y-6"
      onSubmit={(e) => {
        e.preventDefault();
        setError(null);
        setDuplicateId(null);
        startTransition(async () => {
          const result = await createClienteAction({
            name,
            cnpj,
            requester,
            sites,
            cep,
            street,
            number,
            complement,
            neighborhood,
            city,
            state,
            service,
            systemType: systems[0]?.systemType || "",
            baseName,
            baseCargo,
            baseEmail,
            basePhone,
            systems: systems.filter(
              (s) =>
                s.systemType.trim() ||
                s.tag.trim() ||
                s.installLocation.trim() ||
                s.manufacturer.trim(),
            ),
          });
          if (!result.ok) {
            setError(result.error || "Falha ao salvar.");
            if (result.id) setDuplicateId(result.id);
            return;
          }
          router.push(`/clientes/${result.id}`);
          router.refresh();
        });
      }}
    >
      <section className="rounded-3xl border border-navy/10 bg-white p-5 md:p-6">
        <p className="text-[11px] font-semibold uppercase tracking-[0.22em] text-brass">
          Identificação
        </p>
        <h2 className="mt-1 font-serif text-xl text-navy">
          CNPJ e razão social
        </h2>
        <p className="mt-2 mb-4 text-sm text-navy/55">
          Busca na Receita preenche endereço e contato — mesma planilha do GS
          Campo.
        </p>
        <div className="grid gap-3 md:grid-cols-2">
          <div className="md:col-span-2">
            <CnpjField
              value={cnpj}
              onChange={(value) => {
                setCnpj(value);
                setCnpjMessage(null);
                setDuplicateId(null);
              }}
              onLookup={() => {
                void applyLookup();
              }}
              loading={loading}
              message={cnpjMessage}
              error={cnpjError}
            />
          </div>
          <label className="block text-sm md:col-span-2">
            <span className="text-[11px] uppercase tracking-wide text-navy/45">
              Razão / nome *
            </span>
            <input
              required
              value={name}
              onChange={(e) => setName(e.target.value)}
              className={inputClass}
            />
          </label>
          <label className="block text-sm">
            <span className="text-[11px] uppercase tracking-wide text-navy/45">
              Solicitante
            </span>
            <input
              value={requester}
              onChange={(e) => setRequester(e.target.value)}
              className={inputClass}
            />
          </label>
          <label className="block text-sm">
            <span className="text-[11px] uppercase tracking-wide text-navy/45">
              Serviço
            </span>
            <input
              value={service}
              onChange={(e) => setService(e.target.value)}
              className={inputClass}
              placeholder="Calibração, manutenção…"
            />
          </label>
          <label className="block text-sm md:col-span-2">
            <span className="text-[11px] uppercase tracking-wide text-navy/45">
              Sites / bases (separe por | )
            </span>
            <input
              value={sites}
              onChange={(e) => setSites(e.target.value)}
              className={inputClass}
              placeholder="BABET|BASPA"
            />
          </label>
        </div>
      </section>

      <section className="rounded-3xl border border-navy/10 bg-white p-5 md:p-6">
        <p className="text-[11px] font-semibold uppercase tracking-[0.22em] text-brass">
          Endereço
        </p>
        <h2 className="mt-1 font-serif text-xl text-navy">Local do cliente</h2>
        <div className="mt-4 grid gap-3 md:grid-cols-6">
          <label className="block text-sm md:col-span-2">
            <span className="text-[11px] uppercase tracking-wide text-navy/45">
              CEP
            </span>
            <input
              value={cep}
              onChange={(e) => setCep(digitsOnly(e.target.value).slice(0, 8))}
              className={inputClass}
            />
          </label>
          <label className="block text-sm md:col-span-4">
            <span className="text-[11px] uppercase tracking-wide text-navy/45">
              Logradouro
            </span>
            <input
              value={street}
              onChange={(e) => setStreet(e.target.value)}
              className={inputClass}
            />
          </label>
          <label className="block text-sm md:col-span-2">
            <span className="text-[11px] uppercase tracking-wide text-navy/45">
              Número
            </span>
            <input
              value={number}
              onChange={(e) => setNumber(e.target.value)}
              className={inputClass}
            />
          </label>
          <label className="block text-sm md:col-span-2">
            <span className="text-[11px] uppercase tracking-wide text-navy/45">
              Complemento
            </span>
            <input
              value={complement}
              onChange={(e) => setComplement(e.target.value)}
              className={inputClass}
            />
          </label>
          <label className="block text-sm md:col-span-2">
            <span className="text-[11px] uppercase tracking-wide text-navy/45">
              Bairro
            </span>
            <input
              value={neighborhood}
              onChange={(e) => setNeighborhood(e.target.value)}
              className={inputClass}
            />
          </label>
          <label className="block text-sm md:col-span-4">
            <span className="text-[11px] uppercase tracking-wide text-navy/45">
              Cidade
            </span>
            <input
              value={city}
              onChange={(e) => setCity(e.target.value)}
              className={inputClass}
            />
          </label>
          <label className="block text-sm md:col-span-2">
            <span className="text-[11px] uppercase tracking-wide text-navy/45">
              UF
            </span>
            <input
              value={state}
              onChange={(e) =>
                setState(e.target.value.toUpperCase().slice(0, 2))
              }
              className={inputClass}
              maxLength={2}
            />
          </label>
        </div>
      </section>

      <section className="rounded-3xl border border-navy/10 bg-white p-5 md:p-6">
        <p className="text-[11px] font-semibold uppercase tracking-[0.22em] text-brass">
          Contato da base
        </p>
        <h2 className="mt-1 font-serif text-xl text-navy">
          Quem assina / recebe na base
        </h2>
        <div className="mt-4 grid gap-3 md:grid-cols-2">
          <label className="block text-sm">
            <span className="text-[11px] uppercase tracking-wide text-navy/45">
              Nome
            </span>
            <input
              value={baseName}
              onChange={(e) => setBaseName(e.target.value)}
              className={inputClass}
            />
          </label>
          <label className="block text-sm">
            <span className="text-[11px] uppercase tracking-wide text-navy/45">
              Cargo
            </span>
            <input
              value={baseCargo}
              onChange={(e) => setBaseCargo(e.target.value)}
              className={inputClass}
            />
          </label>
          <label className="block text-sm">
            <span className="text-[11px] uppercase tracking-wide text-navy/45">
              E-mail
            </span>
            <input
              type="email"
              value={baseEmail}
              onChange={(e) => setBaseEmail(e.target.value)}
              className={inputClass}
            />
          </label>
          <label className="block text-sm">
            <span className="text-[11px] uppercase tracking-wide text-navy/45">
              Telefone
            </span>
            <input
              value={basePhone}
              onChange={(e) => setBasePhone(e.target.value)}
              className={inputClass}
            />
          </label>
        </div>
      </section>

      <section className="rounded-3xl border border-navy/10 bg-white p-5 md:p-6">
        <div className="flex flex-wrap items-end justify-between gap-3">
          <div>
            <p className="text-[11px] font-semibold uppercase tracking-[0.22em] text-brass">
              Sistemas
            </p>
            <h2 className="mt-1 font-serif text-xl text-navy">
              Conjuntos / instrumentos
            </h2>
            <p className="mt-2 text-sm text-navy/55">
              Opcional no cadastro — dá para incluir depois. Mesmo formato do
              app.
            </p>
          </div>
          <button
            type="button"
            onClick={() => setSystems((prev) => [...prev, emptySystem()])}
            className="rounded-xl border border-navy/15 bg-paper px-3 py-2 text-sm font-semibold text-navy hover:border-brass/40"
          >
            + Sistema
          </button>
        </div>

        <div className="mt-4 space-y-4">
          {systems.map((system, index) => (
            <div
              key={index}
              className="rounded-2xl border border-navy/10 bg-paper/60 p-4"
            >
              <div className="mb-3 flex items-center justify-between gap-2">
                <p className="text-sm font-semibold text-navy">
                  Sistema {index + 1}
                </p>
                {systems.length > 1 ? (
                  <button
                    type="button"
                    onClick={() =>
                      setSystems((prev) => prev.filter((_, i) => i !== index))
                    }
                    className="text-xs font-medium text-navy/45 hover:text-red-700"
                  >
                    Remover
                  </button>
                ) : null}
              </div>
              <div className="grid gap-3 md:grid-cols-2">
                <label className="block text-sm">
                  <span className="text-[11px] uppercase tracking-wide text-navy/45">
                    Tipo do sistema
                  </span>
                  <input
                    value={system.systemType}
                    onChange={(e) =>
                      updateSystem(index, { systemType: e.target.value })
                    }
                    className={inputClass}
                    placeholder="Carregamento/Descarregamento…"
                  />
                </label>
                <label className="block text-sm">
                  <span className="text-[11px] uppercase tracking-wide text-navy/45">
                    Local instalado
                  </span>
                  <input
                    value={system.installLocation}
                    onChange={(e) =>
                      updateSystem(index, { installLocation: e.target.value })
                    }
                    className={inputClass}
                  />
                </label>
                <label className="block text-sm">
                  <span className="text-[11px] uppercase tracking-wide text-navy/45">
                    TAG
                  </span>
                  <input
                    value={system.tag}
                    onChange={(e) =>
                      updateSystem(index, { tag: e.target.value })
                    }
                    className={inputClass}
                  />
                </label>
                <label className="block text-sm">
                  <span className="text-[11px] uppercase tracking-wide text-navy/45">
                    Tipo do conjunto
                  </span>
                  <select
                    value={system.kind}
                    onChange={(e) =>
                      updateSystem(index, { kind: e.target.value })
                    }
                    className={inputClass}
                  >
                    {CLIENT_ASSEMBLY_KINDS.map((k) => (
                      <option key={k.value} value={k.value}>
                        {k.label}
                      </option>
                    ))}
                  </select>
                </label>
                <label className="block text-sm">
                  <span className="text-[11px] uppercase tracking-wide text-navy/45">
                    Fabricante
                  </span>
                  <input
                    value={system.manufacturer}
                    onChange={(e) =>
                      updateSystem(index, { manufacturer: e.target.value })
                    }
                    className={inputClass}
                  />
                </label>
                <label className="block text-sm">
                  <span className="text-[11px] uppercase tracking-wide text-navy/45">
                    Modelo
                  </span>
                  <input
                    value={system.model}
                    onChange={(e) =>
                      updateSystem(index, { model: e.target.value })
                    }
                    className={inputClass}
                  />
                </label>
                <label className="block text-sm">
                  <span className="text-[11px] uppercase tracking-wide text-navy/45">
                    N/S
                  </span>
                  <input
                    value={system.serialNumber}
                    onChange={(e) =>
                      updateSystem(index, { serialNumber: e.target.value })
                    }
                    className={inputClass}
                  />
                </label>
                <label className="block text-sm">
                  <span className="text-[11px] uppercase tracking-wide text-navy/45">
                    TAG do conjunto / preset
                  </span>
                  <input
                    value={system.assemblyTag}
                    onChange={(e) =>
                      updateSystem(index, { assemblyTag: e.target.value })
                    }
                    className={inputClass}
                  />
                </label>
                <label className="block text-sm">
                  <span className="text-[11px] uppercase tracking-wide text-navy/45">
                    Qtd. medidores
                  </span>
                  <input
                    type="number"
                    min={0}
                    value={system.meterCount}
                    onChange={(e) =>
                      updateSystem(index, {
                        meterCount: Number(e.target.value) || 0,
                      })
                    }
                    className={inputClass}
                  />
                </label>
                <label className="block text-sm">
                  <span className="text-[11px] uppercase tracking-wide text-navy/45">
                    Qtd. PT100
                  </span>
                  <input
                    type="number"
                    min={0}
                    value={system.pt100Count}
                    onChange={(e) =>
                      updateSystem(index, {
                        pt100Count: Number(e.target.value) || 0,
                      })
                    }
                    className={inputClass}
                  />
                </label>
                <label className="block text-sm">
                  <span className="text-[11px] uppercase tracking-wide text-navy/45">
                    Qtd. densímetros
                  </span>
                  <input
                    type="number"
                    min={0}
                    value={system.densimeterCount}
                    onChange={(e) =>
                      updateSystem(index, {
                        densimeterCount: Number(e.target.value) || 0,
                      })
                    }
                    className={inputClass}
                  />
                </label>
              </div>
            </div>
          ))}
        </div>
      </section>

      <div className="flex flex-wrap items-center gap-3">
        <button
          type="submit"
          disabled={pending || digitsOnly(cnpj).length !== 14 || !name.trim()}
          className="rounded-xl bg-brass px-5 py-2.5 text-sm font-semibold text-navy hover:bg-brass-2 disabled:opacity-60"
        >
          {pending ? "Salvando na planilha…" : "Salvar cliente"}
        </button>
        <Link
          href="/clientes"
          className="rounded-xl border border-navy/15 bg-white px-4 py-2.5 text-sm font-medium text-navy hover:bg-paper"
        >
          Cancelar
        </Link>
        {error ? (
          <p className="text-sm text-red-700">
            {error}
            {duplicateId ? (
              <>
                {" "}
                <Link
                  href={`/clientes/${duplicateId}`}
                  className="font-semibold underline"
                >
                  Abrir cadastro
                </Link>
              </>
            ) : null}
          </p>
        ) : null}
      </div>
    </form>
  );
}
