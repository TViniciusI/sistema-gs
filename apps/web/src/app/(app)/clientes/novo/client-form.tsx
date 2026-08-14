"use client";

import { useState } from "react";
import { CnpjField } from "@/components/cnpj-field";
import { Button, Field, FormGrid } from "@/components/ui";
import { useCnpjLookup } from "@/hooks/use-cnpj-lookup";
import { createClientRecord } from "../../cadastros/actions";
import type { LocalCnpjRecord } from "@/lib/cnpj";

export function ClientForm({
  localRecords,
  nextCode,
}: {
  localRecords: LocalCnpjRecord[];
  nextCode: number;
}) {
  const { fetchCnpj, loading, error } = useCnpjLookup(localRecords);
  const [cnpj, setCnpj] = useState("");
  const [alias, setAlias] = useState("");
  const [legalName, setLegalName] = useState("");
  const [requester, setRequester] = useState({
    name: "",
    title: "",
    phone: "",
    email: "",
  });
  const [manager, setManager] = useState({
    name: "",
    title: "",
    phone: "",
    email: "",
  });
  const [message, setMessage] = useState<string | null>(null);

  async function applyLookup() {
    const result = await fetchCnpj(cnpj, true);
    if (!result) return;

    setLegalName(result.razaoSocial);
    setAlias(result.nomeFantasia);
    setManager((current) => ({
      ...current,
      phone: result.telefone || current.phone,
      email: result.email || current.email,
    }));
    setMessage(
      result.source === "local"
        ? `Preenchido com o cadastro local (${result.razaoSocial}).`
        : `Preenchido pela Receita Federal (${result.razaoSocial}).`,
    );
  }

  return (
    <form action={createClientRecord} className="space-y-6">
      <FormGrid>
        <Field
          label="Código do cliente"
          name="code"
          type="number"
          required
          defaultValue={nextCode}
        />
        <CnpjField
          value={cnpj}
          onChange={(value) => {
            setCnpj(value);
            setMessage(null);
          }}
          onLookup={() => {
            void applyLookup();
          }}
          loading={loading}
          message={message}
          error={error}
        />
        <Field label="Apelido" name="alias">
          <input
            name="alias"
            value={alias}
            onChange={(event) => setAlias(event.target.value)}
            className="w-full rounded-sm border border-line bg-white px-3 py-2 text-sm text-ink outline-none focus:border-brass"
          />
        </Field>
        <Field label="Contratante / razão social" name="legal_name" required>
          <input
            name="legal_name"
            required
            value={legalName}
            onChange={(event) => setLegalName(event.target.value)}
            className="w-full rounded-sm border border-line bg-white px-3 py-2 text-sm text-ink outline-none focus:border-brass"
          />
        </Field>
      </FormGrid>
      <h2 className="font-serif text-lg text-navy">Solicitante</h2>
      <FormGrid>
        <Field label="Nome" name="requester_name">
          <input
            name="requester_name"
            value={requester.name}
            onChange={(event) =>
              setRequester((current) => ({ ...current, name: event.target.value }))
            }
            className="w-full rounded-sm border border-line bg-white px-3 py-2 text-sm text-ink outline-none focus:border-brass"
          />
        </Field>
        <Field label="Cargo" name="requester_title">
          <input
            name="requester_title"
            value={requester.title}
            onChange={(event) =>
              setRequester((current) => ({ ...current, title: event.target.value }))
            }
            className="w-full rounded-sm border border-line bg-white px-3 py-2 text-sm text-ink outline-none focus:border-brass"
          />
        </Field>
        <Field label="Telefone" name="requester_phone">
          <input
            name="requester_phone"
            value={requester.phone}
            onChange={(event) =>
              setRequester((current) => ({ ...current, phone: event.target.value }))
            }
            className="w-full rounded-sm border border-line bg-white px-3 py-2 text-sm text-ink outline-none focus:border-brass"
          />
        </Field>
        <Field label="E-mail" name="requester_email" type="email">
          <input
            name="requester_email"
            type="email"
            value={requester.email}
            onChange={(event) =>
              setRequester((current) => ({ ...current, email: event.target.value }))
            }
            className="w-full rounded-sm border border-line bg-white px-3 py-2 text-sm text-ink outline-none focus:border-brass"
          />
        </Field>
      </FormGrid>
      <h2 className="font-serif text-lg text-navy">Responsável da base</h2>
      <FormGrid>
        <Field label="Nome" name="manager_name">
          <input
            name="manager_name"
            value={manager.name}
            onChange={(event) =>
              setManager((current) => ({ ...current, name: event.target.value }))
            }
            className="w-full rounded-sm border border-line bg-white px-3 py-2 text-sm text-ink outline-none focus:border-brass"
          />
        </Field>
        <Field label="Cargo" name="manager_title">
          <input
            name="manager_title"
            value={manager.title}
            onChange={(event) =>
              setManager((current) => ({ ...current, title: event.target.value }))
            }
            className="w-full rounded-sm border border-line bg-white px-3 py-2 text-sm text-ink outline-none focus:border-brass"
          />
        </Field>
        <Field label="Telefone" name="manager_phone">
          <input
            name="manager_phone"
            value={manager.phone}
            onChange={(event) =>
              setManager((current) => ({ ...current, phone: event.target.value }))
            }
            className="w-full rounded-sm border border-line bg-white px-3 py-2 text-sm text-ink outline-none focus:border-brass"
          />
        </Field>
        <Field label="E-mail" name="manager_email" type="email">
          <input
            name="manager_email"
            type="email"
            value={manager.email}
            onChange={(event) =>
              setManager((current) => ({ ...current, email: event.target.value }))
            }
            className="w-full rounded-sm border border-line bg-white px-3 py-2 text-sm text-ink outline-none focus:border-brass"
          />
        </Field>
      </FormGrid>
      <Button type="submit">Salvar cliente</Button>
    </form>
  );
}
