-- =====================================================================
-- Migração — Próxima Programação por card (veiculos)
-- Idempotente. Aditiva. Não apaga dados existentes.
-- Rode no SQL Editor do Supabase.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1) Colunas na tabela principal public.veiculos
-- ---------------------------------------------------------------------
alter table public.veiculos
  add column if not exists proxima_programacao text,
  add column if not exists proxima_programacao_observacao text,
  add column if not exists proxima_programacao_data timestamptz,
  add column if not exists proxima_programacao_criada_por text,
  add column if not exists proxima_programacao_criada_em timestamptz,
  add column if not exists proxima_programacao_atualizada_por text,
  add column if not exists proxima_programacao_atualizada_em timestamptz;

-- Índices de leitura
create index if not exists veiculos_com_prox_prog_idx
  on public.veiculos(proxima_programacao)
  where proxima_programacao is not null;

create index if not exists veiculos_sem_prox_prog_idx
  on public.veiculos(id)
  where proxima_programacao is null;

create index if not exists veiculos_prox_prog_data_idx
  on public.veiculos(proxima_programacao_data)
  where proxima_programacao_data is not null;

-- ---------------------------------------------------------------------
-- 2) Tabela de histórico / auditoria
-- ---------------------------------------------------------------------
create table if not exists public.proxima_programacao_historico (
  id uuid primary key default gen_random_uuid(),
  veiculo_id uuid references public.veiculos(id) on delete cascade,
  placa text,
  motorista text,
  acao text not null,                           -- 'criada' | 'atualizada' | 'removida'
  proxima_programacao_anterior text,
  proxima_programacao_nova text,
  observacao_anterior text,
  observacao_nova text,
  data_anterior timestamptz,
  data_nova timestamptz,
  usuario text,
  criado_em timestamptz not null default now()
);

create index if not exists prox_prog_hist_veiculo_idx
  on public.proxima_programacao_historico(veiculo_id, criado_em desc);

create index if not exists prox_prog_hist_criado_em_idx
  on public.proxima_programacao_historico(criado_em desc);

-- ---------------------------------------------------------------------
-- 3) Permissões (Data API / PostgREST)
-- ---------------------------------------------------------------------
grant select, insert, update, delete
  on public.proxima_programacao_historico to anon, authenticated;
grant all on public.proxima_programacao_historico to service_role;

-- ---------------------------------------------------------------------
-- 4) RLS — mesmo padrão aberto do projeto
-- ---------------------------------------------------------------------
alter table public.proxima_programacao_historico enable row level security;

drop policy if exists "prox prog historico full access"
  on public.proxima_programacao_historico;
create policy "prox prog historico full access"
  on public.proxima_programacao_historico
  for all using (true) with check (true);

-- ---------------------------------------------------------------------
-- 5) Trigger — manter proxima_programacao_atualizada_em coerente
--     e gravar histórico automático em INSERT / UPDATE / DELETE.
-- ---------------------------------------------------------------------
create or replace function public.fn_proxima_programacao_audit()
returns trigger
language plpgsql
as $$
declare
  v_usuario text;
  v_old_prog text;
  v_new_prog text;
  v_old_obs text;
  v_new_obs text;
  v_old_data timestamptz;
  v_new_data timestamptz;
  v_acao text;
begin
  if TG_OP = 'DELETE' then
    if OLD.proxima_programacao is null then
      return OLD;
    end if;
    insert into public.proxima_programacao_historico(
      veiculo_id, placa, motorista, acao,
      proxima_programacao_anterior, proxima_programacao_nova,
      observacao_anterior, observacao_nova,
      data_anterior, data_nova, usuario
    ) values (
      OLD.id, OLD.placa, OLD.motorista, 'removida',
      OLD.proxima_programacao, null,
      OLD.proxima_programacao_observacao, null,
      OLD.proxima_programacao_data, null,
      OLD.proxima_programacao_atualizada_por
    );
    return OLD;
  end if;

  v_old_prog := case when TG_OP = 'INSERT' then null else OLD.proxima_programacao end;
  v_new_prog := NEW.proxima_programacao;
  v_old_obs  := case when TG_OP = 'INSERT' then null else OLD.proxima_programacao_observacao end;
  v_new_obs  := NEW.proxima_programacao_observacao;
  v_old_data := case when TG_OP = 'INSERT' then null else OLD.proxima_programacao_data end;
  v_new_data := NEW.proxima_programacao_data;

  -- Só auditar se houve mudança em algum dos campos da próxima programação
  if v_old_prog is not distinct from v_new_prog
     and v_old_obs  is not distinct from v_new_obs
     and v_old_data is not distinct from v_new_data then
    return NEW;
  end if;

  -- Atualiza carimbo de atualização
  NEW.proxima_programacao_atualizada_em := now();

  if v_old_prog is null and v_new_prog is not null then
    v_acao := 'criada';
    if NEW.proxima_programacao_criada_em is null then
      NEW.proxima_programacao_criada_em := now();
    end if;
    if NEW.proxima_programacao_criada_por is null then
      NEW.proxima_programacao_criada_por := NEW.proxima_programacao_atualizada_por;
    end if;
  elsif v_old_prog is not null and v_new_prog is null then
    v_acao := 'removida';
    NEW.proxima_programacao_criada_em := null;
    NEW.proxima_programacao_criada_por := null;
  else
    v_acao := 'atualizada';
  end if;

  v_usuario := NEW.proxima_programacao_atualizada_por;

  insert into public.proxima_programacao_historico(
    veiculo_id, placa, motorista, acao,
    proxima_programacao_anterior, proxima_programacao_nova,
    observacao_anterior, observacao_nova,
    data_anterior, data_nova, usuario
  ) values (
    NEW.id, NEW.placa, NEW.motorista, v_acao,
    v_old_prog, v_new_prog,
    v_old_obs, v_new_obs,
    v_old_data, v_new_data,
    v_usuario
  );

  return NEW;
end;
$$;

drop trigger if exists trg_proxima_programacao_audit on public.veiculos;
create trigger trg_proxima_programacao_audit
  before insert or update or delete on public.veiculos
  for each row execute function public.fn_proxima_programacao_audit();

-- ---------------------------------------------------------------------
-- 6) Realtime
-- ---------------------------------------------------------------------
do $$
begin
  begin
    alter publication supabase_realtime add table public.proxima_programacao_historico;
  exception when duplicate_object then null;
  end;
end$$;

-- veiculos já está em supabase_realtime; novas colunas são publicadas
-- automaticamente para clientes inscritos.

-- =====================================================================
-- Fim da migração
-- =====================================================================
