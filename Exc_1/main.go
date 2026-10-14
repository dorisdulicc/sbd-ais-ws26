package main

import "fmt"

type Message struct {
	Text string
}

func (m Message) Print() {
	fmt.Println(m.Text)
}

func main() {
	hello := Message{
		Text: "Hello World!",
	}

	hello.Print()
}
