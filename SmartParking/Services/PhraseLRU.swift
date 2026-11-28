import Foundation

final class PhraseLRU<Key: Hashable, Value> {
    private final class Node {
        let key: Key
        var value: Value
        var previous: Node?
        var next: Node?

        init(key: Key, value: Value) {
            self.key = key
            self.value = value
        }
    }

    let maxEntries: Int
    private var nodes: [Key: Node] = [:]
    private var head: Node?
    private var tail: Node?

    init(maxEntries: Int) {
        precondition(maxEntries > 0)
        self.maxEntries = maxEntries
    }

    var count: Int {
        nodes.count
    }

    var keysByUse: [Key] {
        var keys: [Key] = []
        var node = head
        while let current = node {
            keys.append(current.key)
            node = current.next
        }
        return keys
    }

    func value(for key: Key) -> Value? {
        guard let node = nodes[key] else { return nil }
        moveToFront(node)
        return node.value
    }

    func set(_ value: Value, for key: Key) {
        if let node = nodes[key] {
            node.value = value
            moveToFront(node)
            return
        }
        let node = Node(key: key, value: value)
        nodes[key] = node
        insertAtFront(node)
        if nodes.count > maxEntries, let last = tail {
            unlink(last)
            nodes[last.key] = nil
        }
    }

    private func moveToFront(_ node: Node) {
        guard head !== node else { return }
        unlink(node)
        insertAtFront(node)
    }

    private func insertAtFront(_ node: Node) {
        node.previous = nil
        node.next = head
        head?.previous = node
        head = node
        if tail == nil {
            tail = node
        }
    }

    private func unlink(_ node: Node) {
        node.previous?.next = node.next
        node.next?.previous = node.previous
        if head === node {
            head = node.next
        }
        if tail === node {
            tail = node.previous
        }
        node.previous = nil
        node.next = nil
    }
}
