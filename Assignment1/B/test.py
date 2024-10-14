class A:
	def __init__(self, a: int) -> None:
		self.a = a



if __name__ == "__main__":
	a = A(1)

	objs = [A(i) for i in range(10)] + [a]

	print(objs.index(a))
	