defmodule Duel.Game.Math.Problem do
  def generate do
    operator = Enum.random([:+, :-])

    {a, b, correct_answer} = generate_problem(operator)

    options =
      Enum.shuffle([
        %{value: correct_answer},
        %{value: correct_answer + Enum.random(1..5)},
        %{value: correct_answer - Enum.random(1..5)}
      ])

    %{
      question: "#{a} #{operator} #{b}",
      correct_answer: correct_answer,
      options: options
    }
  end

  defp generate_problem(:+) do
    a = Enum.random(1..50)
    b = Enum.random(1..50)

    {a, b, a + b}
  end

  defp generate_problem(:-) do
    a = Enum.random(20..99)
    b = Enum.random(1..a)

    {a, b, a - b}
  end
end
