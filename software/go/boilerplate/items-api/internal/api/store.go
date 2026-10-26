package api

import (
	"maps"
	"sync"
)

// Item is any JSON object.
type Item = map[string]any

// Store is what the API needs from storage. A database-backed implementation
// satisfies the same interface, with no change to the HTTP layer.
type Store interface {
	Get(id string) (Item, bool)
	Put(id string, item Item)
	Delete(id string)
}

// MemoryStore keeps items in a map, safe for concurrent use. Data is lost on
// restart: for local use and tests only.
type MemoryStore struct {
	mu    sync.RWMutex // many readers or one writer at a time
	items map[string]Item
}

// NewMemoryStore returns an empty MemoryStore.
func NewMemoryStore() *MemoryStore {
	return &MemoryStore{items: make(map[string]Item)}
}

// Get returns a copy of the item, so callers can't change stored data.
func (s *MemoryStore) Get(id string) (Item, bool) {
	s.mu.RLock()
	defer s.mu.RUnlock()
	item, ok := s.items[id]
	return maps.Clone(item), ok
}

// Put stores a copy of the item, replacing any existing one.
func (s *MemoryStore) Put(id string, item Item) {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.items[id] = maps.Clone(item)
}

// Delete removes the item; deleting a missing item is not an error.
func (s *MemoryStore) Delete(id string) {
	s.mu.Lock()
	defer s.mu.Unlock()
	delete(s.items, id)
}
