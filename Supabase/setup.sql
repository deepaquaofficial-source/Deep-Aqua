-- DEEP Aqua Business Suite — Supabase database setup
-- Run this once in Supabase: Dashboard → SQL Editor → New query → paste → Run.
-- It creates the tables, the access rules (row level security) and the user-role system.
-- Safe to run again: it only adds what is missing.
--
-- Users: create every login in Supabase → Authentication → Users → Add user.
-- New logins start as "pending" (no access). Make yourself Admin with the line at the
-- very bottom of this file; after that, give roles from the app's Users & roles screen.

create extension if not exists pgcrypto;

-- ---------- user profiles & roles ----------
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text,
  name text,
  role text not null default 'pending'
    check (role in ('admin','manager','accounts','sales','store','distributor','agency','pending')),
  active boolean not null default true,
  customer_id uuid,               -- for distributor / agency logins: which customer account they see
  created_at timestamptz not null default now()
);

create or replace function public.my_role() returns text
language sql stable security definer set search_path = public as $$
  select case when active then role else 'pending' end from public.profiles where id = auth.uid()
$$;

create or replace function public.my_customer() returns text
language sql stable security definer set search_path = public as $$
  select customer_id::text from public.profiles where id = auth.uid()
$$;

create or replace function public.is_staff() returns boolean
language sql stable as $$
  select coalesce(public.my_role() in ('admin','manager','accounts','sales','store'), false)
$$;

-- every new login gets a profile, waiting for approval
create or replace function public.handle_new_user() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id, email, name, role)
  values (new.id, new.email,
          coalesce(new.raw_user_meta_data->>'name', split_part(new.email,'@',1)),
          'pending')
  on conflict (id) do nothing;
  return new;
end $$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users
  for each row execute function public.handle_new_user();

alter table public.profiles enable row level security;
drop policy if exists "profiles read" on public.profiles;
create policy "profiles read" on public.profiles for select to authenticated
  using (id = auth.uid() or public.my_role() in ('admin','manager'));
drop policy if exists "profiles admin update" on public.profiles;
create policy "profiles admin update" on public.profiles for update to authenticated
  using (public.my_role() = 'admin') with check (public.my_role() = 'admin');
drop policy if exists "profiles admin delete" on public.profiles;
create policy "profiles admin delete" on public.profiles for delete to authenticated
  using (public.my_role() = 'admin');

-- ---------- business tables ----------
-- Every business table has the same shape: id, a JSON "data" document, and audit columns.
-- The app stores invoice lines, totals, GST split etc. inside "data".
do $$
declare t text;
begin
  foreach t in array array['company','brands','products','customers','suppliers',
                           'sales','sales_returns','purchases','purchase_returns','wastage','receipts']
  loop
    execute format($f$
      create table if not exists public.%I (
        id uuid primary key default gen_random_uuid(),
        data jsonb not null default '{}'::jsonb,
        created_at timestamptz not null default now(),
        created_by uuid default auth.uid(),
        updated_at timestamptz not null default now()
      )$f$, t);
    execute format('create index if not exists %1$s_created_idx on public.%1$I (created_at)', t);
    execute format('alter table public.%I enable row level security', t);
    execute format('drop policy if exists "staff read" on public.%I', t);
    execute format('drop policy if exists "staff write" on public.%I', t);
    execute format('drop policy if exists "staff update" on public.%I', t);
    execute format('drop policy if exists "admin delete" on public.%I', t);
    execute format('create policy "staff read" on public.%I for select to authenticated using (public.is_staff())', t);
    execute format('create policy "staff write" on public.%I for insert to authenticated with check (public.is_staff())', t);
    execute format('create policy "staff update" on public.%I for update to authenticated using (public.is_staff()) with check (public.is_staff())', t);
    execute format('create policy "admin delete" on public.%I for delete to authenticated using (public.my_role() in (''admin'',''manager''))', t);
  end loop;
end $$;

-- distributors / agencies: read the company, brands and products, and only their own bills
drop policy if exists "partner read catalogue" on public.products;
create policy "partner read catalogue" on public.products for select to authenticated
  using (public.my_role() in ('distributor','agency'));
drop policy if exists "partner read brands" on public.brands;
create policy "partner read brands" on public.brands for select to authenticated
  using (public.my_role() in ('distributor','agency'));
drop policy if exists "partner read company" on public.company;
create policy "partner read company" on public.company for select to authenticated
  using (public.my_role() in ('distributor','agency'));
drop policy if exists "partner own customer" on public.customers;
create policy "partner own customer" on public.customers for select to authenticated
  using (public.my_role() in ('distributor','agency') and id::text = public.my_customer());
do $$
declare t text;
begin
  foreach t in array array['sales','sales_returns','receipts'] loop
    execute format('drop policy if exists "partner own docs" on public.%I', t);
    execute format('create policy "partner own docs" on public.%I for select to authenticated using (public.my_role() in (''distributor'',''agency'') and data->>''customer_id'' = public.my_customer())', t);
  end loop;
end $$;

-- keep updated_at fresh
create or replace function public.touch() returns trigger language plpgsql as $$
begin new.updated_at = now(); return new; end $$;
do $$
declare t text;
begin
  foreach t in array array['company','brands','products','customers','suppliers',
                           'sales','sales_returns','purchases','purchase_returns','wastage','receipts']
  loop
    execute format('drop trigger if exists touch_%1$s on public.%1$I', t);
    execute format('create trigger touch_%1$s before update on public.%1$I for each row execute function public.touch()', t);
  end loop;
end $$;

-- ---------- starting data (edit prices in the app) ----------
insert into public.company (data)
select jsonb_build_object(
  'name','DEEP Aqua','legal','LST Private Limited','gstin','','state','Tamil Nadu',
  'address','Salem, Tamil Nadu 636 001, India','phone','',
  'email_general','info@deepaqua.in','email_sales','sales@deepaqua.in','email_support','support@deepaqua.in',
  'email_purchase','purchase@deepaqua.in','email_admin','admin@deepaqua.in','website','www.deepaqua.in',
  'bank','','account','','ifsc','','prefix','DA',
  'terms','Goods once sold will be taken back only as per return policy. Subject to Salem jurisdiction.')
where not exists (select 1 from public.company);

insert into public.brands (data)
select '{"name":"DEEP","note":"Packaged drinking water in paper carton"}'::jsonb
where not exists (select 1 from public.brands);

-- ---------- profiles for logins created before this script ran ----------
insert into public.profiles (id, email, name, role)
select u.id, u.email, split_part(u.email,'@',1), 'pending'
from auth.users u
where not exists (select 1 from public.profiles p where p.id = u.id);

-- ---------- MAKE YOURSELF ADMIN ----------
-- 1. Authentication → Users → Add user → your email + password (tick "Auto Confirm User").
-- 2. Change the email below to that same email, select only this line, and Run.
-- update public.profiles set role = 'admin', active = true where email = 'admin@deepaqua.in';
   update public.profiles set role = 'admin', active = true where email = 'admin@deepaqua.in';
