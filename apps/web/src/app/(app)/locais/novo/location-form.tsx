"use client";

import { useState } from "react";
import { maskCnpj } from "@gs/shared";
import { CnpjField } from "@/components/cnpj-field";
import { Button, Field, FormGrid, SelectField } from "@/components/ui";
import { useCnpjLookup } from "@/hooks/use-cnpj-lookup";
import { createLocationRecord } from "../../cadastros/actions";
import type { LocalCnpjRecord } from "@/lib/cnpj";

type ClientOption = {
  id: string;
  label: string;
  cnpj: string;
};

export function LocationForm({
  clients,
  localRecords,
}: {
  clients: ClientOption[];
  localRecords: LocalCnpjRecord[];
}) {
  const { fetchCnpj, loading, error } = useCnpjLookup(localRecords);
  const [clientId, setClientId] = useState(clients[0]?.id ?? "");
  const [cnpj, setCnpj] = useState(() => maskCnpj(clients[0]?.cnpj ?? ""));
  const [alias, setAlias] = useState("");
  const [city, setCity] = useState("");
  const [state, setState] = useState("");
  const [address, setAddress] = useState("");
  const [message, setMessage] = useState<string | null>(null);

  async function applyLookup(force = false) {
    const result = await fetchCnpj(cnpj, force);
    if (!result) return;

    setAlias(result.nomeFantasia);
    setCity(result.cidade);
    setState(result.estado);
    setAddress(result.endereco);
    if (result.clientId) {
      setClientId(result.clientId);
    }
    setMessage(
      result.source === "local"
        ? `Preenchido com o cadastro local (${result.razaoSocial}).`
        : `Preenchido pela Receita Federal (${result.razaoSocial}).`,
    );
  }

  function handleClientChange(id: string) {
    setClientId(id);
    const client = clients.find((item) => item.id === id);
    const local = localRecords.find((item) => item.clientId === id);
    if (client) setCnpj(maskCnpj(client.cnpj));
    if (local) {
      setAlias(local.nomeFantasia);
      setCity(local.cidade ?? "");
      setState(local.estado ?? "");
      setAddress(local.endereco ?? "");
      setMessage(`Preenchido com o cadastro local (${local.razaoSocial}).`);
      return;
    }
    setMessage(null);
  }

  return (
    <form action={createLocationRecord} className="space-y-6">
      <SelectField
        label="Cliente"
        name="client_id"
        required
        value={clientId}
        onChange={(event) => handleClientChange(event.target.value)}
        options={clients.map((client) => ({
          value: client.id,
          label: client.label,
        }))}
      />

      <CnpjField
        value={cnpj}
        onChange={(value) => {
          setCnpj(value);
          setMessage(null);
        }}
        onLookup={() => {
          void applyLookup(true);
        }}
        loading={loading}
        message={message}
        error={error}
      />
      <p className="text-xs text-muted">
        Digite os 14 dígitos e clique em Buscar (ou saia do campo). Na
        demonstração, {maskCnpj("02345678000190")} preenche a ALESAT/MG.
      </p>

      <FormGrid>
        <Field label="Apelido da base" name="alias" required>
          <input
            name="alias"
            required
            value={alias}
            onChange={(event) => setAlias(event.target.value)}
            className="w-full rounded-sm border border-line bg-white px-3 py-2 text-sm text-ink outline-none focus:border-brass"
          />
        </Field>
        <Field label="Cidade" name="city">
          <input
            name="city"
            value={city}
            onChange={(event) => setCity(event.target.value)}
            className="w-full rounded-sm border border-line bg-white px-3 py-2 text-sm text-ink outline-none focus:border-brass"
          />
        </Field>
        <Field label="UF" name="state">
          <input
            name="state"
            value={state}
            onChange={(event) => setState(event.target.value)}
            className="w-full rounded-sm border border-line bg-white px-3 py-2 text-sm text-ink outline-none focus:border-brass"
          />
        </Field>
        <Field label="Endereço" name="address">
          <input
            name="address"
            value={address}
            onChange={(event) => setAddress(event.target.value)}
            className="w-full rounded-sm border border-line bg-white px-3 py-2 text-sm text-ink outline-none focus:border-brass"
          />
        </Field>
      </FormGrid>
      <Button type="submit">Salvar local</Button>
    </form>
  );
}
