package main

import (
	"bufio"
	"log"
	"os"
	"path/filepath"
	"strings"
	"sync"

	"github.com/miekg/dns"
	"gopkg.in/yaml.v3"
)

// Config - структура для хранения наших настроек
type Config struct {
	ListenAddress    string `yaml:"listen_address"`
	ForwarderAddress string `yaml:"forwarder_address"`
	BlacklistsDir    string `yaml:"blacklists_dir"` // Изменили поле
	LogLevel         string `yaml:"log_level"`
}

// Глобальные переменные для хранения настроек и черного списка
var (
	config    Config
	blacklist = &sync.Map{}
)

// loadConfig загружает конфигурацию из файла .yaml
func loadConfig(filename string) {
	log.Printf("Загрузка конфигурации из файла: %s", filename)
	data, err := os.ReadFile(filename)
	if err != nil {
		log.Fatalf("Ошибка при чтении файла конфигурации: %v", err)
	}

	err = yaml.Unmarshal(data, &config)
	if err != nil {
		log.Fatalf("Ошибка при разборе файла конфигурации: %v", err)
	}

	// Устанавливаем значения по умолчанию
	if config.ListenAddress == "" {
		config.ListenAddress = "0.0.0.0:53"
	}
	if config.ForwarderAddress == "" {
		config.ForwarderAddress = "8.8.8.8:53"
	}
	if config.BlacklistsDir == "" {
		config.BlacklistsDir = "blacklists" // Папка по умолчанию
	}
	if config.LogLevel != "debug" {
		config.LogLevel = "info"
	}

	log.Printf("Конфигурация успешно загружена.")
	log.Printf(" - Адрес прослушивания: %s", config.ListenAddress)
	log.Printf(" - DNS-форвардер: %s", config.ForwarderAddress)
	log.Printf(" - Папка с чёрными списками: %s", config.BlacklistsDir)
	log.Printf(" - Уровень логирования: %s", config.LogLevel)
}

// loadBlacklists сканирует папку и загружает домены из всех .txt файлов.
func loadBlacklists() {
	dir := config.BlacklistsDir
	log.Printf("Загрузка чёрных списков из папки: %s", dir)

	// Читаем содержимое директории
	files, err := os.ReadDir(dir)
	if err != nil {
		log.Printf("Внимание: не удалось прочитать папку с чёрными списками '%s': %v", dir, err)
		return
	}

	totalDomains := 0
	// Проходим по каждому файлу в папке
	for _, file := range files {
		// Нас интересуют только файлы (не папки) с расширением .txt
		if !file.IsDir() && strings.HasSuffix(strings.ToLower(file.Name()), ".txt") {
			path := filepath.Join(dir, file.Name())
			log.Printf("...Читаем файл: %s", path)

			f, err := os.Open(path)
			if err != nil {
				log.Printf("Ошибка при открытии файла списка %s: %v", path, err)
				continue // Пропускаем этот файл и идем к следующему
			}

			scanner := bufio.NewScanner(f)
			count := 0
			for scanner.Scan() {
				domain := strings.TrimSpace(scanner.Text())
				if domain != "" && !strings.HasPrefix(domain, "#") {
					blacklist.Store(domain, true)
					count++
				}
			}
			f.Close() // Важно закрыть файл после чтения

			if err := scanner.Err(); err != nil {
				log.Printf("Ошибка при чтении файла списка %s: %v", path, err)
			} else {
				log.Printf("...Из файла %s загружено %d доменов.", file.Name(), count)
				totalDomains += count
			}
		}
	}
	log.Printf("Всего загружено %d доменов в чёрный список из %d файлов.", totalDomains, len(files))
}

func handleDnsRequest(w dns.ResponseWriter, r *dns.Msg) {
	if len(r.Question) == 0 {
		dns.HandleFailed(w, r)
		return
	}

	question := r.Question[0]
	domain := strings.TrimSuffix(question.Name, ".")

	if config.LogLevel == "debug" {
		log.Printf("DEBUG: Получен запрос для домена: %s, тип: %s", domain, dns.TypeToString[question.Qtype])
	}

	if _, found := blacklist.Load(domain); found {
		if config.LogLevel != "debug" {
			log.Printf("БЛОКИРОВКА: Домен %s (тип %s)", domain, dns.TypeToString[question.Qtype])
		}
		
		m := new(dns.Msg)
		m.SetRcode(r, dns.RcodeNameError)
		w.WriteMsg(m)
		return
	}

	if config.LogLevel != "debug" && !strings.HasSuffix(domain, "in-addr.arpa") && !strings.HasSuffix(domain, "ip6.arpa") {
		log.Printf("РАЗРЕШЕНО: Перенаправление запроса для %s", domain)
	}
	
	c := new(dns.Client)
	in, _, err := c.Exchange(r, config.ForwarderAddress)
	if err != nil {
		log.Printf("Ошибка при перенаправлении запроса для %s: %v", domain, err)
		dns.HandleFailed(w, r)
		return
	}

	w.WriteMsg(in)
}

func main() {
	loadConfig("config.yaml")
	loadBlacklists() // Изменили вызов

	dns.HandleFunc(".", handleDnsRequest)
	server := &dns.Server{Addr: config.ListenAddress, Net: "udp"}

	log.Printf("Запускаем DNS-фильтр...")
	err := server.ListenAndServe()
	if err != nil {
		log.Fatalf("Не удалось запустить сервер: %s\nВОЗМОЖНАЯ ПРИЧИНА: Запустите программу от имени Администратора.", err)
	}
	defer server.Shutdown()
}