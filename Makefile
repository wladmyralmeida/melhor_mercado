# melhor mercado — alvos do dia a dia

.PHONY: setup gen watch run test check format analyze clean

setup: ## Dependências + codegen
	flutter pub get
	dart run build_runner build

gen: ## Regenera o código do Drift
	dart run build_runner build

watch: ## Codegen contínuo durante o desenvolvimento
	dart run build_runner watch

run: ## Roda no dispositivo/emulador conectado
	flutter run

test: ## Suite completa (timeout por teste: travou, falhou)
	flutter test --timeout 60s

check: ## O gate local = o gate do CI
	dart format --set-exit-if-changed .
	dart analyze --fatal-infos
	flutter test --timeout 60s

format:
	dart format .

analyze:
	dart analyze

clean:
	flutter clean
