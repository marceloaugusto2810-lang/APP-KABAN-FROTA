-- =====================================================================
-- Remoção da autenticação / roles vinculadas a auth.users
-- Rode manualmente no SQL Editor do Supabase. Idempotente.
-- =====================================================================

-- 1) folgas_ausencias.criado_por: virar TEXTO livre --------------------
-- Remove FK para auth.users e converte a coluna para text (nome livre).
do $$
declare
  fk_name text;
begin
  select conname into fk_name
    from pg_constraint
   where conrelid = 'public.folgas_ausencias'::regclass
     and contype = 'f'
     and conname like '%criado_por%';
  if fk_name is not null then
    execute format('alter table public.folgas_ausencias drop constraint %I', fk_name);
  end if;
end $$;

alter table public.folgas_ausencias
  alter column criado_por drop default,
  alter column criado_por type text using criado_por::text;

-- 2) Remover policies que dependem de auth/has_role -------------------
drop policy if exists "folgas delete master" on public.folgas_ausencias;
drop policy if exists "folgas insert auth" on public.folgas_ausencias;
drop policy if exists "folgas update auth" on public.folgas_ausencias;
drop policy if exists "folgas read auth" on public.folgas_ausencias;

drop policy if exists "caminhoes_meta delete master" on public.caminhoes_meta;
drop policy if exists "caminhoes_meta update auth" on public.caminhoes_meta;
drop policy if exists "caminhoes_meta write auth" on public.caminhoes_meta;
drop policy if exists "caminhoes_meta read auth" on public.caminhoes_meta;

-- Policies abertas (sem login) — usa a anon key normalmente.
create policy "folgas all anon" on public.folgas_ausencias
  for all to anon, authenticated using (true) with check (true);

create policy "caminhoes_meta all anon" on public.caminhoes_meta
  for all to anon, authenticated using (true) with check (true);

-- 3) GRANTs para anon (sem autenticação) ------------------------------
grant select, insert, update, delete on public.folgas_ausencias to anon;
grant select, insert, update, delete on public.caminhoes_meta   to anon;

-- 4) Remover estrutura de roles/has_role/user_roles -------------------
drop policy if exists "user_roles self read"    on public.user_roles;
drop policy if exists "user_roles master write" on public.user_roles;

drop function if exists public.has_role(uuid, public.app_role);
drop table    if exists public.user_roles;
drop type     if exists public.app_role;

-- =====================================================================
-- Fim. Após rodar, o app funciona sem tela de login.
-- =====================================================================
