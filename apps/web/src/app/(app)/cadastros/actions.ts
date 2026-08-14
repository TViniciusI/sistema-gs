"use server";

import { redirect } from "next/navigation";
import { digitsOnly } from "@gs/shared";
import { getDemo } from "@/lib/demo/store";

export async function createClientRecord(formData: FormData) {
  const id = `cli-${Date.now()}`;
  getDemo().clients.push({
    id,
    code: Number(formData.get("code") || 0),
    alias: String(formData.get("alias") ?? "").trim() || "NOVA BASE",
    legalName: String(formData.get("legal_name") ?? "").trim() || "Novo cliente",
    cnpj: digitsOnly(String(formData.get("cnpj") ?? "")),
    requester: {
      name: String(formData.get("requester_name") ?? "").trim() || "—",
      title: String(formData.get("requester_title") ?? "").trim() || "—",
      phone: String(formData.get("requester_phone") ?? "").trim() || "—",
      email: String(formData.get("requester_email") ?? "").trim() || "—",
    },
    manager: {
      name: String(formData.get("manager_name") ?? "").trim() || "—",
      title: String(formData.get("manager_title") ?? "").trim() || "—",
      phone: String(formData.get("manager_phone") ?? "").trim() || "—",
      email: String(formData.get("manager_email") ?? "").trim() || "—",
    },
  });
  redirect(`/clientes/${id}`);
}

export async function createLocationRecord(formData: FormData) {
  getDemo().locations.push({
    id: `loc-${Date.now()}`,
    clientId: String(formData.get("client_id")),
    alias: String(formData.get("alias") ?? "").trim(),
    address: String(formData.get("address") ?? "").trim(),
    city: String(formData.get("city") ?? "").trim(),
    state: String(formData.get("state") ?? "").trim(),
  });
  redirect("/locais");
}

export async function createEmployeeRecord(formData: FormData) {
  const field = formData.get("is_technician") === "on";
  const id = `emp-${Date.now()}`;
  getDemo().employees.push({
    id,
    technicianId: field ? `tec-${Date.now()}` : undefined,
    name: String(formData.get("full_name") ?? "").trim(),
    title: String(formData.get("job_title") ?? "").trim(),
    phone: String(formData.get("phone") ?? "").trim(),
    field,
  });
  redirect("/equipe");
}
