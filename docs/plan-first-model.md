# Plan: First Domain-Specific Small Language Model

Build a small language model (SLM) from scratch, trained on domain-specific data,
deployable on the Pi cluster. Based on the approach from
[Building a Small Language Model from Scratch](https://medium.com/@rajasami408/building-a-small-language-model-from-scratch-a-practical-guide-to-domain-specific-ai-59539131437f).

---

## Goals

- Understand the full stack: data → tokenizer → model architecture → training → inference
- Keep the model small enough to run inference on the Pi 5 (CPU or Hailo-10H)
- Train on domain-specific data so the model answers questions about a defined topic
- Use this as a foundation for understanding transformer internals before working with larger models

---

## Phase 1: Data Collection

Gather domain-specific text into a single `corpus.txt` file. The model will only know
what is in this file — scope it tightly to a topic.

**Options for this project:**
- Pi cluster documentation (setup guides, hardware specs, Hailo docs)
- Raspberry Pi OS / Hailo SDK documentation
- Your own notes and README files

**Steps:**
1. Scrape or copy relevant text into `corpus.txt`
2. Clean the data — remove HTML, navigation, boilerplate
3. Aim for at least a few thousand words; more is better up to the model capacity

---

## Phase 2: Tokenizer

Train a character-level or byte-pair encoding (BPE) tokenizer on the corpus.

```python
# Simple character-level tokenizer
chars = sorted(set(open('corpus.txt').read()))
vocab_size = len(chars)
stoi = {ch: i for i, ch in enumerate(chars)}
itos = {i: ch for i, ch in enumerate(chars)}
encode = lambda s: [stoi[c] for c in s]
decode = lambda l: ''.join([itos[i] for i in l])
```

**Split data:**
```python
import torch
data = torch.tensor(encode(open('corpus.txt').read()), dtype=torch.long)
n = int(0.9 * len(data))
train_data = data[:n]
val_data   = data[n:]
```

---

## Phase 3: Model Architecture

### Hyperparameters (start small)

```python
embedding_dim  = 128   # size of token embeddings
n_heads        = 4     # number of attention heads
head_size      = embedding_dim // n_heads   # 32
n_blocks       = 4     # transformer layers
block_size     = 64    # context window (tokens)
dropout        = 0.1
```

### Attention

Scaled dot-product attention with causal masking — each token can only attend to
itself and prior tokens, not future ones.

```python
class Attention(nn.Module):
    def __init__(self, head_size):
        super().__init__()
        self.key   = nn.Linear(embedding_dim, head_size, bias=False)
        self.query = nn.Linear(embedding_dim, head_size, bias=False)
        self.value = nn.Linear(embedding_dim, head_size, bias=False)
        self.register_buffer('tril', torch.tril(torch.ones(block_size, block_size)))

    def forward(self, x):
        B, T, C = x.shape
        k = self.key(x)
        q = self.query(x)
        # Causal mask: set future positions to -inf so softmax zeros them out
        weights = q @ k.transpose(-2, -1) * C**-0.5
        weights = weights.masked_fill(self.tril[:T, :T] == 0, float('-inf'))
        weights = F.softmax(weights, dim=-1)
        return weights @ self.value(x)
```

### MultiHeadAttention + TransformerBlock

```python
class MultiHeadAttention(nn.Module):
    def __init__(self, n_heads, head_size):
        super().__init__()
        self.heads = nn.ModuleList([Attention(head_size) for _ in range(n_heads)])
        self.proj  = nn.Linear(embedding_dim, embedding_dim)

    def forward(self, x):
        return self.proj(torch.cat([h(x) for h in self.heads], dim=-1))

class TransformerBlock(nn.Module):
    def __init__(self):
        super().__init__()
        self.attn = MultiHeadAttention(n_heads, head_size)
        self.ff   = nn.Sequential(
            nn.Linear(embedding_dim, 4 * embedding_dim),
            nn.ReLU(),
            nn.Linear(4 * embedding_dim, embedding_dim),
        )
        self.ln1 = nn.LayerNorm(embedding_dim)
        self.ln2 = nn.LayerNorm(embedding_dim)

    def forward(self, x):
        x = x + self.attn(self.ln1(x))
        x = x + self.ff(self.ln2(x))
        return x
```

### Full Model

```python
class SmallLanguageModel(nn.Module):
    def __init__(self):
        super().__init__()
        self.token_embedding    = nn.Embedding(vocab_size, embedding_dim)
        self.position_embedding = nn.Embedding(block_size, embedding_dim)
        self.blocks = nn.Sequential(*[TransformerBlock() for _ in range(n_blocks)])
        self.ln     = nn.LayerNorm(embedding_dim)
        self.head   = nn.Linear(embedding_dim, vocab_size)

    def forward(self, idx, targets=None):
        B, T = idx.shape
        tok_emb = self.token_embedding(idx)
        pos_emb = self.position_embedding(torch.arange(T))
        x = self.blocks(self.ln(tok_emb + pos_emb))
        logits = self.head(x)
        loss = F.cross_entropy(logits.view(-1, vocab_size), targets.view(-1)) if targets is not None else None
        return logits, loss
```

---

## Phase 4: Training

Train on a Mac or GPU workstation (not on the Pi — training is CPU/GPU intensive).
2,000 steps is a reasonable starting point for a small corpus.

```python
optimizer = torch.optim.AdamW(model.parameters(), lr=1e-3)

for step in range(2000):
    xb, yb = get_batch('train')
    logits, loss = model(xb, yb)
    optimizer.zero_grad()
    loss.backward()
    optimizer.step()
    if step % 200 == 0:
        print(f"step {step}: loss {loss.item():.4f}")
```

**Model sizing guidance:**
- Too large for your data → overfitting (low train loss, high val loss)
- Too small for your data → underfitting (both losses plateau high)
- Monitor train vs validation loss to find the right balance

---

## Phase 5: Export and Deploy to Pi

Export the trained model for inference on the Pi:

```python
torch.save(model.state_dict(), 'slm.pt')
```

**Inference on Pi (CPU):**
```python
model.load_state_dict(torch.load('slm.pt', map_location='cpu'))
model.eval()
```

**Hailo-10H (stretch goal):**
Compile the model to HEF format using the Hailo Dataflow Compiler (requires x86
workstation). Deploy to `/dev/hailo0` on control node.

---

## Sizing Reference

| Parameter | Small | Medium |
|-----------|-------|--------|
| embedding_dim | 64–128 | 256–512 |
| n_heads | 2–4 | 4–8 |
| n_blocks | 2–4 | 6–12 |
| block_size | 32–64 | 128–256 |
| Training tokens | ~100K | ~1M+ |
| Model size | ~1MB | ~10–50MB |

Start small — get it working end-to-end first, then scale up.

---

## File Structure

```
50-slm/
  corpus.txt          # domain-specific training data
  tokenizer.py        # character or BPE tokenizer
  model.py            # Attention, TransformerBlock, SLM classes
  train.py            # training loop
  infer.py            # inference script for Pi
  slm.pt              # trained weights (gitignored if large)
```
