# Change Log

All notable changes to this project will be documented in this file.
See [Conventional Commits](Https://conventionalcommits.org) for commit guidelines.

<!-- changelog -->

## [v0.2.92](https://github.com/ash-project/ash_sql/compare/v0.2.91...v0.2.92) (2025-09-01)




### Bug Fixes:

* retain joined relationships for distinct requirements by [@zachdaniel](https://github.com/zachdaniel)

## [v0.2.91](https://github.com/ash-project/ash_sql/compare/v0.2.90...v0.2.91) (2025-08-31)




### Bug Fixes:

* handle case where sort is not set in bindings by [@zachdaniel](https://github.com/zachdaniel)

## [v0.2.90](https://github.com/ash-project/ash_sql/compare/v0.2.89...v0.2.90) (2025-08-21)




### Bug Fixes:

* Sanitize distinct in joins (#168) by [@jechol](https://github.com/jechol)

* don't distinct aggregate subqueries by [@zachdaniel](https://github.com/zachdaniel)

* Expand distinct with sort order (#162) by Kenneth Kostrešević

### Improvements:

* support unrelated aggregates (#164) by [@zachdaniel](https://github.com/zachdaniel)

## [v0.2.89](https://github.com/ash-project/ash_sql/compare/v0.2.88...v0.2.89) (2025-07-25)




### Bug Fixes:

* pull tenant from query properly by [@zachdaniel](https://github.com/zachdaniel)

## [v0.2.88](https://github.com/ash-project/ash_sql/compare/v0.2.87...v0.2.88) (2025-07-23)




### Bug Fixes:

* add missing pattern match on exists aggregate by [@zachdaniel](https://github.com/zachdaniel)

## [v0.2.87](https://github.com/ash-project/ash_sql/compare/v0.2.86...v0.2.87) (2025-07-22)




### Bug Fixes:

* include references within `exists` while building calculation joins by [@zachdaniel](https://github.com/zachdaniel)

* make it clear that we don't support aggregates w/ modify_query by [@zachdaniel](https://github.com/zachdaniel)

## [v0.2.86](https://github.com/ash-project/ash_sql/compare/v0.2.85...v0.2.86) (2025-07-17)




### Bug Fixes:

* ensure aggregates set `refs_at_path` and calc hydration uses them by [@zachdaniel](https://github.com/zachdaniel)

* ensure that decimal-producing calculations cast args as decimals by [@zachdaniel](https://github.com/zachdaniel)

## [v0.2.85](https://github.com/ash-project/ash_sql/compare/v0.2.84...v0.2.85) (2025-07-09)




### Bug Fixes:

* ensure we join nested parent references properly by [@zachdaniel](https://github.com/zachdaniel)

## [v0.2.84](https://github.com/ash-project/ash_sql/compare/v0.2.83...v0.2.84) (2025-07-02)




### Bug Fixes:

* handle parent paths in first relationship of exists path by [@zachdaniel](https://github.com/zachdaniel)

## [v0.2.83](https://github.com/ash-project/ash_sql/compare/v0.2.82...v0.2.83) (2025-06-25)




### Bug Fixes:

* ensure calculations are properly type cast by [@zachdaniel](https://github.com/zachdaniel)

## [v0.2.82](https://github.com/ash-project/ash_sql/compare/v0.2.81...v0.2.82) (2025-06-18)




### Improvements:

* optimize/simplify boolean functions like && and || by [@zachdaniel](https://github.com/zachdaniel)

## [v0.2.81](https://github.com/ash-project/ash_sql/compare/v0.2.80...v0.2.81) (2025-06-17)




### Improvements:

* fix another double-type-casting issue by [@zachdaniel](https://github.com/zachdaniel)

## [v0.2.80](https://github.com/ash-project/ash_sql/compare/v0.2.79...v0.2.80) (2025-06-12)




### Bug Fixes:

* don't double cast literals by [@zachdaniel](https://github.com/zachdaniel)

## [v0.2.79](https://github.com/ash-project/ash_sql/compare/v0.2.78...v0.2.79) (2025-06-10)




### Bug Fixes:

* ensure that subqueries have prefix set on atomic update selection by [@zachdaniel](https://github.com/zachdaniel)

* apply subquery schema on many-to-many relationships (#143) by kernel-io

## [v0.2.78](https://github.com/ash-project/ash_sql/compare/v0.2.77...v0.2.78) (2025-06-05)




### Bug Fixes:

* always cast operator types, even simple ones

* undo change that prevents casting literals

## [v0.2.77](https://github.com/ash-project/ash_sql/compare/v0.2.76...v0.2.77) (2025-06-04)




### Bug Fixes:

* clean up a whole slew of ecto hacks that arent necessary

* don't implicitly cast all values

### Improvements:

* reduce cases of double-typecasting

## [v0.2.76](https://github.com/ash-project/ash_sql/compare/v0.2.75...v0.2.76) (2025-05-23)




### Bug Fixes:

* retain constraints when type casting

## [v0.2.75](https://github.com/ash-project/ash_sql/compare/v0.2.74...v0.2.75) (2025-05-06)




### Bug Fixes:

* use higher start bindings to avoid shadowing (#133)

* fix calculation remapping post-distinct

### Improvements:

* support combination queries (#131)

* support combination queries

* Support rem through fragment (#130)

## [v0.2.74](https://github.com/ash-project/ash_sql/compare/v0.2.73...v0.2.74) (2025-05-01)




### Bug Fixes:

* don't group aggregates w/ parent refs

## [v0.2.73](https://github.com/ash-project/ash_sql/compare/v0.2.72...v0.2.73) (2025-04-29)




### Bug Fixes:

* prefix subqueries for atomic validations

* change start_of_day

## [v0.2.72](https://github.com/ash-project/ash_sql/compare/v0.2.71...v0.2.72) (2025-04-22)




### Bug Fixes:

* prefix subqueries for atomic validations

* change start_of_day

## [v0.2.71](https://github.com/ash-project/ash_sql/compare/v0.2.70...v0.2.71) (2025-04-17)




### Bug Fixes:

* convert tz properly for start_of_day

## [v0.2.70](https://github.com/ash-project/ash_sql/compare/v0.2.69...v0.2.70) (2025-04-17)




### Bug Fixes:

* handle query aggregate in aggregate field properly

## [v0.2.69](https://github.com/ash-project/ash_sql/compare/v0.2.68...v0.2.69) (2025-04-15)




### Bug Fixes:

* pass correct operation to split_statements (#121)

## [v0.2.68](https://github.com/ash-project/ash_sql/compare/v0.2.67...v0.2.68) (2025-04-15)




### Bug Fixes:

* duplicate aggregate pruning was pruning non-duplicates

* handle map type logic natively in ash_sql instead of extensions

## [v0.2.67](https://github.com/ash-project/ash_sql/compare/v0.2.66...v0.2.67) (2025-04-09)




### Bug Fixes:

* we do need to set the binding, but can just give it a unique name

* remove explicitly set binding.

## [v0.2.66](https://github.com/ash-project/ash_sql/compare/v0.2.65...v0.2.66) (2025-03-26)




### Bug Fixes:

* set proper `refs_at_path` for `exists` queries

## [v0.2.65](https://github.com/ash-project/ash_sql/compare/v0.2.64...v0.2.65) (2025-03-26)




### Bug Fixes:

* call `.to_tenant` on the ash query, not the ecto query

## [v0.2.64](https://github.com/ash-project/ash_sql/compare/v0.2.63...v0.2.64) (2025-03-26)




### Improvements:

* use new fill_template fn (#115)

## [v0.2.63](https://github.com/ash-project/ash_sql/compare/v0.2.62...v0.2.63) (2025-03-25)




### Bug Fixes:

* handle embeds typed as json/jsonb/map

## [v0.2.62](https://github.com/ash-project/ash_sql/compare/v0.2.61...v0.2.62) (2025-03-18)




### Bug Fixes:

* support aggregate queries that are against aggregates or calcs

* add handling for multidimensional arrays in `IN` operator

## [v0.2.61](https://github.com/ash-project/ash_sql/compare/v0.2.60...v0.2.61) (2025-03-11)




### Bug Fixes:

* don't use embedded resources as expressions

* hydrate aggregate expressions at the target

## [v0.2.60](https://github.com/ash-project/ash_sql/compare/v0.2.59...v0.2.60) (2025-03-03)




### Bug Fixes:

* properly join to parent paths in aggregate filters

## [v0.2.59](https://github.com/ash-project/ash_sql/compare/v0.2.58...v0.2.59) (2025-02-27)




### Bug Fixes:

* wrap strpos comparison in parenthesis

## [v0.2.58](https://github.com/ash-project/ash_sql/compare/v0.2.57...v0.2.58) (2025-02-25)




### Bug Fixes:

* various binding index fixes

* use new functions in `ash` for proper expansion

* use `count()` when no field is provided for count aggregate

## [v0.2.57](https://github.com/ash-project/ash_sql/compare/v0.2.56...v0.2.57) (2025-02-17)




### Bug Fixes:

* rewrite loaded calculations in distinct subqueries

* ensure literal maps are casted to maps in atomic update select

* cast complex types in operator signatures

## [v0.2.56](https://github.com/ash-project/ash_sql/compare/v0.2.55...v0.2.56) (2025-02-11)




### Bug Fixes:

* more consistent tz handling in `start_of_day`

## [v0.2.55](https://github.com/ash-project/ash_sql/compare/v0.2.54...v0.2.55) (2025-02-11)




### Improvements:

* add StringPosition expression (#98) (#99)

## [v0.2.54](https://github.com/ash-project/ash_sql/compare/v0.2.53...v0.2.54) (2025-02-08)




### Bug Fixes:

* properly join to aggregates in `parent` exprs in relationships

* handle non-utc timezoned databases

* join requirements in parent exprs in first relationship of aggregates

## [v0.2.53](https://github.com/ash-project/ash_sql/compare/v0.2.52...v0.2.53) (2025-02-05)




### Bug Fixes:

* simplify lateral join source

## [v0.2.52](https://github.com/ash-project/ash_sql/compare/v0.2.51...v0.2.52) (2025-02-04)




### Bug Fixes:

* ensure single agg query has bindings

## [v0.2.51](https://github.com/ash-project/ash_sql/compare/v0.2.50...v0.2.51) (2025-02-03)




### Bug Fixes:

* don't attempt to cast to `nil`

* Use modified query instead of original when calling add_single_aggs (#94)

## [v0.2.50](https://github.com/ash-project/ash_sql/compare/v0.2.49...v0.2.50) (2025-01-31)




### Bug Fixes:

* properly handle database time zones in `start_of_day/1-2`

## [v0.2.49](https://github.com/ash-project/ash_sql/compare/v0.2.48...v0.2.49) (2025-01-30)




### Improvements:

* support `start_of_day/1-2`

## [v0.2.48](https://github.com/ash-project/ash_sql/compare/v0.2.47...v0.2.48) (2025-01-23)




### Bug Fixes:

* handle nested many to many binding overlaps

## [v0.2.47](https://github.com/ash-project/ash_sql/compare/v0.2.46...v0.2.47) (2025-01-22)




### Bug Fixes:

* properly fetch source query for many to many rels

## [v0.2.46](https://github.com/ash-project/ash_sql/compare/v0.2.45...v0.2.46) (2025-01-20)




### Improvements:

* support `no_cast?` in bindings while expr parsing

## [v0.2.45](https://github.com/ash-project/ash_sql/compare/v0.2.44...v0.2.45) (2025-01-14)




### Bug Fixes:

* ensure that referenced fields are joined in agg queries

## [v0.2.44](https://github.com/ash-project/ash_sql/compare/v0.2.43...v0.2.44) (2025-01-06)




### Bug Fixes:

* filter query by source record ids when lateral joining

* use `normalize` for string length

* use right value for resource aggregate default in sort (#85)

* handle resource aggregate with function default in sort (#84)

## [v0.2.43](https://github.com/ash-project/ash_sql/compare/v0.2.42...v0.2.43) (2024-12-26)




### Bug Fixes:

* return `{:empty, query}` on empty atomic changes

## [v0.2.42](https://github.com/ash-project/ash_sql/compare/v0.2.41...v0.2.42) (2024-12-20)




### Bug Fixes:

* properly bind many to many relationships in aggregates

## [v0.2.41](https://github.com/ash-project/ash_sql/compare/v0.2.40...v0.2.41) (2024-12-12)




### Bug Fixes:

* apply attribute multitenancy on joined resources

* use lateral join for parent_expr many to many joins

* ensure join binding is available for join resource in exists

* add missing pattern for setting group context

## [v0.2.40](https://github.com/ash-project/ash_sql/compare/v0.2.39...v0.2.40) (2024-12-06)




### Improvements:

* various fixes to the methodology behind type determination

## [v0.2.39](https://github.com/ash-project/ash_sql/compare/v0.2.38...v0.2.39) (2024-11-04)




### Bug Fixes:

* properly reference `from_many?` source binding while joining

## [v0.2.38](https://github.com/ash-project/ash_sql/compare/v0.2.37...v0.2.38) (2024-10-29)




### Bug Fixes:

* ensure we join on parent expressions when joining filtered relationships

## [v0.2.37](https://github.com/ash-project/ash_sql/compare/v0.2.36...v0.2.37) (2024-10-28)




### Bug Fixes:

* properly determine join style for parent expressions

* count: use asterisk if not distinct by field is given (#72)

## [v0.2.36](https://github.com/ash-project/ash_sql/compare/v0.2.35...v0.2.36) (2024-10-08)




### Bug Fixes:

* properly handle parent bindings in aggregate references

## [v0.2.35](https://github.com/ash-project/ash_sql/compare/v0.2.34...v0.2.35) (2024-10-07)




### Bug Fixes:

* properly group aggregates together

* don't attempt to add multiple filter statements to a single aggregate

## [v0.2.34](https://github.com/ash-project/ash_sql/compare/v0.2.33...v0.2.34) (2024-09-27)




### Bug Fixes:

* use `NULL` for cases where we get `nil` values. We actually want `nil` here.

## [v0.2.33](https://github.com/ash-project/ash_sql/compare/v0.2.32...v0.2.33) (2024-09-26)




### Bug Fixes:

* don't reorder selects when modifying for subquery presence

## [v0.2.25](https://github.com/ash-project/ash_sql/compare/v0.2.24...v0.2.25) (2024-07-22)




### Bug Fixes:

* track subqueries while selecting atomics

## [v0.2.24](https://github.com/ash-project/ash_sql/compare/v0.2.23...v0.2.24) (2024-07-17)




### Bug Fixes:

* properly determine `parent_as` bindings for nested joins

## [v0.2.23](https://github.com/ash-project/ash_sql/compare/v0.2.22...v0.2.23) (2024-07-17)




### Bug Fixes:

* fix build

* properly expand resource calculation/aggregates in fields

## [v0.2.22](https://github.com/ash-project/ash_sql/compare/v0.2.21...v0.2.22) (2024-07-16)




### Bug Fixes:

* properly adjust calculation expressions before adding to query

* properly traverse nested maps in non-select contexts

* pass correct resource down when adding calculation fields

## [v0.2.21](https://github.com/ash-project/ash_sql/compare/v0.2.20...v0.2.21) (2024-07-16)




### Bug Fixes:

* move `FILTER` outside of `array_agg` aggregation

* properly honor `include_nil?` option on sorted first aggregates

## [v0.2.20](https://github.com/ash-project/ash_sql/compare/v0.2.19...v0.2.20) (2024-07-15)




### Bug Fixes:

* don't set load on anonymous aggregates

## [v0.2.19](https://github.com/ash-project/ash_sql/compare/v0.2.18...v0.2.19) (2024-07-15)




### Bug Fixes:

* match on old return types for `determine_types` code

## [v0.2.18](https://github.com/ash-project/ash_sql/compare/v0.2.17...v0.2.18) (2024-07-15)




### Bug Fixes:

* properly set aggregate query context

## [v0.2.17](https://github.com/ash-project/ash_sql/compare/v0.2.16...v0.2.17) (2024-07-14)




### Improvements:

* use `determine_types/3` in callback

## [v0.2.16](https://github.com/ash-project/ash_sql/compare/v0.2.15...v0.2.16) (2024-07-14)




### Bug Fixes:

* cast atomics when creating expressions

### Improvements:

* support latest format for type determination type

## [v0.2.15](https://github.com/ash-project/ash_sql/compare/v0.2.14...v0.2.15) (2024-07-13)




### Bug Fixes:

* use original field for type signal when selecting atomics

## [v0.2.14](https://github.com/ash-project/ash_sql/compare/v0.2.13...v0.2.14) (2024-07-13)




### Improvements:

* use explicit `NULL` fragment in error type hints

## [v0.2.13](https://github.com/ash-project/ash_sql/compare/v0.2.12...v0.2.13) (2024-07-12)



### Bug Fixes:

* use expression type for atomic updates

## [v0.2.12](https://github.com/ash-project/ash_sql/compare/v0.2.11...v0.2.12) (2024-07-12)




### Bug Fixes:

* properly handle nested `nil` filters in boolean statements

## [v0.2.11](https://github.com/ash-project/ash_sql/compare/v0.2.10...v0.2.11) (2024-07-11)




### Improvements:

* select pkey so data layers don't have to

## [v0.2.10](https://github.com/ash-project/ash_sql/compare/v0.2.9...v0.2.10) (2024-07-08)




### Bug Fixes:

* ensure selected atomics are also reversed

## [v0.2.9](https://github.com/ash-project/ash_sql/compare/v0.2.8...v0.2.9) (2024-07-08)




### Bug Fixes:

* retain original order for atomics statements

## [v0.2.8](https://github.com/ash-project/ash_sql/compare/v0.2.7...v0.2.8) (2024-07-06)




### Improvements:

* handle `{:array, :map}` stored as `:map`

## [v0.2.7](https://github.com/ash-project/ash_sql/compare/v0.2.6...v0.2.7) (2024-06-27)




### Bug Fixes:

* prefer resource's static prefix over current query's prefix

## [v0.2.6](https://github.com/ash-project/ash_sql/compare/v0.2.5...v0.2.6) (2024-06-18)




### Bug Fixes:

* ensure we always honor `atomics_at_binding` option from data layer

## [v0.2.5](https://github.com/ash-project/ash_sql/compare/v0.2.4...v0.2.5) (2024-06-13)




### Bug Fixes:

* properly remap selects on nested subqueries

## [v0.2.4](https://github.com/ash-project/ash_sql/compare/v0.2.3...v0.2.4) (2024-06-13)




### Bug Fixes:

* remap nested selects when sort requires a subquery

* don't create dynamics for map atomics where there are no expressions

### Improvements:

* only use `jsonb_build_object` for expressions, not literals

## [v0.2.3](https://github.com/ash-project/ash_sql/compare/v0.2.2...v0.2.3) (2024-06-06)




### Bug Fixes:

* various fixes to retain lateral join context

## [v0.2.2](https://github.com/ash-project/ash_sql/compare/v0.2.1...v0.2.2) (2024-06-05)




### Bug Fixes:

* carry over tenant in joined queries

## [v0.2.1](https://github.com/ash-project/ash_sql/compare/v0.2.0...v0.2.1) (2024-06-02)




### Improvements:

* select dynamics uses `__new_` prefix

## [v0.2.0](https://github.com/ash-project/ash_sql/compare/v0.1.3...v0.2.0) (2024-05-29)




### Features:

* add auto dispatch of dynamic_expr calls to behaviour module (#33)

* add auto dispatch of dynamic_expr calls to behaviour module

### Bug Fixes:

* match on new & old parameterized types

### Improvements:

* support selecting atomic results into a subquery, and using those as the atomic values

## [v0.1.3](https://github.com/ash-project/ash_sql/compare/v0.1.2...v0.1.3) (2024-05-22)




### Bug Fixes:

* handle anonymous sorting aggregates

* properly set aggregate source binding when adding aggregate calculations

* use period notation to access aggregate context fields (#30)

* use SQL standard = instead of non standard == (#28)

## [v0.1.2](https://github.com/ash-project/ash_sql/compare/v0.1.1-rc.20...v0.1.2) (2024-05-10)




## [v0.1.1-rc.20](https://github.com/ash-project/ash_sql/compare/v0.1.1-rc.19...v0.1.1-rc.20) (2024-05-08)




### Bug Fixes:

* don't use `fragment("1")` because ecto requires a proper select

## [v0.1.1-rc.19](https://github.com/ash-project/ash_sql/compare/v0.1.1-rc.18...v0.1.1-rc.19) (2024-05-05)




### Bug Fixes:

* use calculation context, and set calculation constraints for aggregates

## [v0.1.1-rc.18](https://github.com/ash-project/ash_sql/compare/v0.1.1-rc.17...v0.1.1-rc.18) (2024-05-05)




### Bug Fixes:

* don't use `ilike` if its not supported

* use type for now expr if available

## [v0.1.1-rc.17](https://github.com/ash-project/ash_sql/compare/v0.1.1-rc.16...v0.1.1-rc.17) (2024-05-02)




### Bug Fixes:

* use manual relationship impl for exists subqueries

## [v0.1.1-rc.16](https://github.com/ash-project/ash_sql/compare/v0.1.1-rc.15...v0.1.1-rc.16) (2024-05-01)




### Bug Fixes:

* hydrate & fill template for related queries

## [v0.1.1-rc.15](https://github.com/ash-project/ash_sql/compare/v0.1.1-rc.14...v0.1.1-rc.15) (2024-04-29)




### Bug Fixes:

* properly support custom expressions

## [v0.1.1-rc.14](https://github.com/ash-project/ash_sql/compare/v0.1.1-rc.13...v0.1.1-rc.14) (2024-04-29)




### Bug Fixes:

* fix argument order in AshSql.Bindings.default_bindings/4

* query_with_atomics pattern matching error

* fix argument order in AshSql.Bindings.default_bindings/4

## [v0.1.1-rc.13](https://github.com/ash-project/ash_sql/compare/v0.1.1-rc.12...v0.1.1-rc.13) (2024-04-27)




### Improvements:

* better inner-join-ability detection

## [v0.1.1-rc.12](https://github.com/ash-project/ash_sql/compare/v0.1.1-rc.11...v0.1.1-rc.12) (2024-04-26)




### Improvements:

* better type casting logic

## [v0.1.1-rc.11](https://github.com/ash-project/ash_sql/compare/v0.1.1-rc.10...v0.1.1-rc.11) (2024-04-23)




### Bug Fixes:

* ensure tenant is properly set in aggregates

* properly pass context through when expanding calculations in aggregates

## [v0.1.1-rc.10](https://github.com/ash-project/ash_sql/compare/v0.1.1-rc.9...v0.1.1-rc.10) (2024-04-22)




### Improvements:

* optimize `contains` when used with literal strings

## [v0.1.1-rc.9](https://github.com/ash-project/ash_sql/compare/v0.1.1-rc.8...v0.1.1-rc.9) (2024-04-22)




### Bug Fixes:

* make `strpos_function` overridable (sqlite uses `instr`)

## [v0.1.1-rc.8](https://github.com/ash-project/ash_sql/compare/v0.1.1-rc.7...v0.1.1-rc.8) (2024-04-22)




### Bug Fixes:

* handle non-literal lists in string join

## [v0.1.1-rc.7](https://github.com/ash-project/ash_sql/compare/v0.1.1-rc.6...v0.1.1-rc.7) (2024-04-20)




### Bug Fixes:

* ensure that `from_many?` is properly honored

* ensure applied query gets joined

* apply related filter inside of related subquery

## [v0.1.1-rc.6](https://github.com/ash-project/ash_sql/compare/v0.1.1-rc.5...v0.1.1-rc.6) (2024-04-12)




### Improvements:

* apply aggregate filters on first join aggregates

## [v0.1.1-rc.5](https://github.com/ash-project/ash_sql/compare/v0.1.1-rc.4...v0.1.1-rc.5) (2024-04-11)




### Bug Fixes:

* don't use to_tenant

* loosen elixir requirements

### Improvements:

* automatically wrap fragments in parenthesis

* remove unnecessary parenthesis from builtin fragments

## [v0.1.1-rc.4](https://github.com/ash-project/ash_sql/compare/v0.1.1-rc.3...v0.1.1-rc.4) (2024-04-05)




### Improvements:

* loosen ash rc restriction

## [v0.1.1-rc.3](https://github.com/ash-project/ash_sql/compare/v0.1.1-rc.2...v0.1.1-rc.3) (2024-04-01)




### Bug Fixes:

* fixes for `ash_postgres`

## [v0.1.1-rc.2](https://github.com/ash-project/ash_sql/compare/v0.1.1-rc.1...v0.1.1-rc.2) (2024-04-01)




### Improvements:

* refactoring out and parameterization to support ash_sqlite

## [v0.1.1-rc.1](https://github.com/ash-project/ash_sql/compare/v0.1.1-rc.0...v0.1.1-rc.1) (2024-04-01)




### Improvements:

* remove postgres-specific copy-pasta

## [v0.1.1-rc.0](https://github.com/ash-project/ash_sql/compare/v0.1.0...v0.1.1-rc.0) (2024-04-01)




## [v0.1.0](https://github.com/ash-project/ash_sql/compare/v0.1.0...v0.1.0) (2024-04-01)




### Improvements:

* extract a bunch of things out of AshPostgres
