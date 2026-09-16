# Power Fit に与える統計量と目的関数

## 結論

Power Fit が近似すべき量は、観測された総パワー

\[
S_{xx}=E[|X|^2],\qquad S_{yy}=E[|Y|^2]
\]

そのものではなく、同一の潜在信号に由来する **coherent signal power**

\[
C_{xx},\qquad C_{yy},\qquad
|G|^2=\frac{C_{yy}}{C_{xx}}
\]

である。したがって既存の正制約 Power LS へ渡す基本行は

\[
M_l=\sqrt{w_l\rho_l}
\begin{bmatrix}
C_{xx,l}\,\phi_b(t_l)^T&-C_{yy,l}\,\phi_a(t_l)^T
\end{bmatrix},
\qquad t_l=\cos(2\pi\omega_l)
\]

とする。ここで \(w_l\) は利用者が指定する設計重み、\(\rho_l\) は統計的な信頼度であり、両者は別の意味を持つ。

この選択には次の限定がある。

- RLS などが返す「決定論的な複素振幅の推定量」からは、\(C_{xx}=|\mu_X|^2\)、\(C_{yy}=|\mu_Y|^2\) を作る。推定分散は目標パワーへ加算せず、\(\rho\) を下げるために使う。
- 定常ランダム信号の標本から得た \(S_{xx},S_{yy},S_{xy}\) からは、雑音モデルに基づいて coherent なランク 1 成分 \(C\) を分離してから使う。一般にこの場合の Fourier 係数はゼロ平均なので、\(|E[X]|^2\) を目的量にはできない。
- \(X,Y\) の両側に未知の測定雑音があるとき、\(S_{xx},S_{yy},S_{xy}\) だけから \(C\) と雑音を一意には分離できない。雑音スペクトル行列、雑音比、独立な反復観測などの追加情報が必要である。
- ガウス定常過程を仮定した統計的な第一選択は spectral-matrix の Whittle likelihood（平均化スペクトルなら complex-Wishart likelihood）である。ただしこれは通常、現在の一回の凸二次最小化にはならない。上式は、その制約を維持するための coherent-power WLS 近似である。
- power の二乗誤差が振幅の四乗次元を持つこと、および Gaussian closure から四次モーメントを導くこと自体は問題ではない。先に固定すべきなのは、何を power の観測量とみなし、どの雑音モデルの下で latent coherent power を識別するかである。

したがって、**現行の確率変数 Power adapter は「推定された決定論的振幅」の adapter としては妥当だが、一般の生スペクトルに対する EIV 最尤推定器ではない**。生の \(S_{xx},S_{yy},S_{xy}\) を受ける adapter は別にし、雑音モデルを明示させる。

## 1. 二種類の確率変数を区別する

### 1.1 決定論的振幅の推定誤差

RLS/最小二乗などが固定された複素振幅 \(x_0,y_0\) を推定し、

\[
\widehat X=x_0+e_x,\qquad
\widehat Y=y_0+e_y
\]

を返す場合を考える。上流から渡される

\[
\mu_X=E[\widehat X],\quad
v_X=E[|\widehat X-\mu_X|^2],\quad
c_{xy}=E[(\widehat X-\mu_X)(\widehat Y-\mu_Y)^*]
\]

は、信号そのものの PSD ではなく、**推定量の分布**である。この場合に近似したい決定論的パワーは

\[
C_{xx}=|\mu_X|^2,\qquad C_{yy}=|\mu_Y|^2
\]

であり、\(v_X,v_Y\) を加えた \(E[|\widehat X|^2]\) ではない。後者を使うと、推定が不確かなほど目標パワーが増えるという望ましくない挙動になる。

現行 adapter の

\[
\rho_{\mu}
=\frac{|\mu_X\mu_Y^*+c_{xy}|^2}
{(|\mu_X|^2+v_X)(|\mu_Y|^2+v_Y)}
\]

は、2 変量の二次モーメント行列から得る squared coherence である。Cauchy--Schwarz により理想的な整合データでは \(0\leq\rho_\mu\leq1\) となり、分散がゼロかつ \(\mu_X,\mu_Y\neq0\) なら \(\rho_\mu=1\) である。このため

\[
(X,Y,w)=(|\mu_X|^2,|\mu_Y|^2,w\rho_\mu)
\]

と既存の決定変数版へ渡せば、分散ゼロで同じ行列・同じ解になる。

この式と共分散の役割は、一次近似からも確認できる。\(g_0=\mu_Y/\mu_X\) とし、推定誤差が proper complex Gaussian なら、平均値が示す関係を壊す相対誤差は

\[
\kappa
=\frac{E[|e_Y-g_0e_X|^2]}{|\mu_Y|^2}
=\frac{v_X}{|\mu_X|^2}+\frac{v_Y}{|\mu_Y|^2}
-2\operatorname{Re}\frac{c_{xy}}{\mu_X\mu_Y^*}.
\]

また delta method では

\[
\operatorname{Var}\!\left(
\log|\widehat Y|^2-
\log|\widehat X|^2
\right)\simeq2\kappa.
\]

現行の \(\rho_\mu\) は小誤差で

\[
\rho_\mu=1-\kappa+O(\|V\|^2)
\]

となるため、\(1/(1+\kappa)\) と同じ一次挙動を持つ有界な reliability と解釈できる。共通モード誤差が伝達比を壊さない向きに完全相関していれば \(\kappa=0\) となるので、単に \(v_X+v_Y\) だけで重みを下げるより共分散を正しく利用している。

ただしこれは信頼度を coherence で近似する設計であり、両側誤差に対する厳密な ML/GTLS 重みではない。\(\mu_X\) または \(\mu_Y\) がゼロに近い場合には上の局所展開も退化する。その bin は「既知のゼロ」と「情報不足」を上流のモデルで区別し、伝達比の情報がなければ \(\rho=0\) とする。

### 1.2 定常ランダム信号のスペクトル

一方、定常ランダム過程の DFT 係数は通常ゼロ平均であり得る。この場合

\[
|E[X_l]|^2=|E[Y_l]|^2=0
\]

でも、LTI 関係は

\[
S_{yx}(\omega)=G(\omega)S_{xx}(\omega)
\]

として cross spectrum に現れる。Tangirala は、入力と出力外乱が無相関という仮定の下でこの関係から \(G=S_{yu}/S_{uu}\) を導き、平滑化した自己・相互スペクトル比を consistent な FRF 推定量としている（提供 PDF pp. 1965--1998, §20.4.2--20.5）。Ljung も同じ spectral-analysis estimator と、入力・外乱スペクトルに依存する漸近分散を示している（提供 PDF pp. 241--255, §6.3--6.4）。

したがって raw spectral adapter では、RLS adapter の \(|\mu|^2\) という式を流用してはならない。流用できるのは \(C_{xx},C_{yy},\rho\) を得た**後**の設計行列生成と正制約ソルバーだけである。

## 2. 生スペクトルから coherent power を作る

観測ベクトルを

\[
z=\begin{bmatrix}X\\Y\end{bmatrix}
=\begin{bmatrix}1\\G\end{bmatrix}s+n
\]

とする。そのスペクトル行列は

\[
S_z=C+N,\qquad
C=\Phi_s
\begin{bmatrix}1\\G\end{bmatrix}
\begin{bmatrix}1&G^*\end{bmatrix}
\]

であり、理想的な \(C\) は Hermitian PSD かつ rank 1 である。Power Fit が必要とするのは \(C\) の対角成分である。

ここで \(P,Q\) はプラントから観測する量ではない。これらは

\[
P(t_l)C_{xx,l}=Q(t_l)C_{yy,l}
\]

を満たすように推定するモデル変数である。また \(C_{xx}\) は励振源の coherent power、\(C_{yy}\) はそれがプラントを通った coherent power なので、プラント固有の観測量は絶対値ではなく

\[
\frac{C_{yy}}{C_{xx}}=|G|^2
\]

である。\((C_{xx},C_{yy})\) の共通尺度は nuisance parameter であり、周波数ごとの行スケールまたは重みに吸収できる。

### 2.1 出力雑音だけを仮定できる場合

入力が無雑音で、出力雑音が入力と無相関なら

\[
C_{xx}=S_{xx},\qquad
C_{yy}=\frac{|S_{yx}|^2}{S_{xx}}
=\gamma^2 S_{yy},
\]

\[
\gamma^2=\frac{|S_{yx}|^2}{S_{xx}S_{yy}}
=\frac{1}{1+1/\mathrm{SNR}}
\]

となる。\(C_{yy}\) は総出力パワーではなく、入力と線形に coherent な出力パワーである。残差雑音は

\[
S_{vv}=S_{yy}-\frac{|S_{yx}|^2}{S_{xx}}
\]

で推定できる。これらは Ljung の coherency と disturbance-spectrum estimator（提供 PDF pp. 254--255, Eqs. 6.78--6.79）、Tangirala の coherence--SNR 関係（提供 PDF pp. 974--980, Eq. 11.54）および disturbance-spectrum estimator（提供 PDF pp. 1993--1994, Eq. 20.64）に対応する。

この仮定の下では \(\rho=\gamma^2\) は明確な意味を持つ。ただし \(C_{yy}=\gamma^2S_{yy}\) としたうえでさらに \(w\gamma^2\) を用いるかは別の設計判断である。前者は目標量から incoherent noise を除く処理、後者はその bin の拘束力を下げる処理であり、役割は重複しない。

この導出に白色雑音の仮定は不要である。\(S_{vv}(\omega)\) は着色していてよく、必要なのは各周波数で入力と出力外乱が無相関であることだけである。相関があれば \(S_{yx}=GS_{xx}\) が成立せず、別の雑音モデルまたは instrumental variable が必要になる。

### 2.2 両側に測定雑音があり、雑音行列が既知の場合

\(N(\omega)\succ0\) が既知または別途推定できるなら、各 bin で

\[
W=N^{-1/2}\widehat S_zN^{-H/2}
\]

を作る。理想モデルでは \(W=I+\) rank-1 signal なので、最大固有対 \((\lambda_1,u_1)\) から

\[
\widehat C
=N^{1/2}\,[\max(\lambda_1-1,0)u_1u_1^H]N^{H/2}
\]

を得る。これは雑音共分散で whiten した PCA/TLS に相当し、\(N\) が非等方・相関雑音であっても扱える。有限標本で \(\widehat S_z-N\) が非 PSD または rank 1 から外れる場合にも、物理的な coherent 成分へ射影できる。

White, Tan and Hammond は、入力・出力の双方に加法雑音がある FRF 推定で PCA が TLS に対応し、既知の雑音共分散を用いる ML が generalized TLS になることを示している。Zhang and Pintelon は、両側が noisy な EIV 問題では FRF と雑音分散の consistent estimation に識別条件が必要であることを扱っている。

### 2.3 雑音行列が未知の場合

観測された 2x2 行列 \(S_z\) だけでは、一般の \(C\) と \(N\) の分解は識別不能である。したがって API が暗黙に推測してはならない。少なくとも次のいずれかを指定させる。

- output-error model（入力無雑音、出力雑音は入力と無相関）
- 既知または推定済みの \(N_{xx},N_{yy},N_{xy}\)
- 雑音分散比・構造
- 独立な反復、複数実験、instrumental variable などの識別情報

例えば \(N=\sigma^2I\) を仮定すれば、\(S_z\) の固有値 \(\lambda_1\geq\lambda_2\) から

\[
\widehat C=(\lambda_1-\lambda_2)u_1u_1^H
\]

とできるが、これは白色・等分散・無相関という強いモデルを採用した結果であり、一般解ではない。

## 3. 目的関数の選択

### 3.1 統計的な基準解

適切に平均化された Fourier 係数を circular complex Gaussian とみなすと、標本スペクトル行列には complex-Wishart モデルが使える。各周波数の有効平均数を \(L_l\)、モデルスペクトル行列を \(\Sigma_l(\vartheta,\nu)\) とすれば、定数を除く負の対数尤度は

\[
J_{\mathrm W}(\vartheta,\nu)
=\sum_l L_l\left[
\log\det\Sigma_l
+\operatorname{tr}(\Sigma_l^{-1}\widehat S_l)
\right]
\]

である。\(\vartheta\) は伝達関数、\(\nu\) は信号・雑音スペクトルなどの nuisance parameter を表す。これは raw periodogram の各要素を正規分布と仮定する方法ではない。

Spagnolini は、Gaussian process の DFT bin が漸近的に Gaussian でも、その絶対値二乗である periodogram は指数分布（自由度 2 の中心 \(\chi^2\)）となり、生 periodogram の分散は大きいことを示している（提供 PDF pp. 399--408, §14.1.4--14.2.1）。同書は Gaussian data に対する parametric PSD likelihood、Whittle 近似、Fisher information/CRB も扱う（提供 PDF pp. 413--415, §14.2.2）。したがって Power 値を便宜的に Gaussian として WLS するより、利用可能なら spectral-matrix likelihood の方が解析的に整合する。

ただし \(J_{\mathrm W}\) は \(P,Q\) に対して一般に非線形であり、nuisance parameter の profile 化を含めれば反復が必要になる。これは「正制約付きの凸二次問題を一回解く」という現在の Power Fit の目的とは別の solver family として扱うべきである。

### 3.2 現在の一回の正制約 LS に採用する近似

現在の solver には

\[
J_{\mathrm{P}}(p,q)
=\sum_l w_l\rho_l
\left(C_{xx,l}P(t_l)-C_{yy,l}Q(t_l)\right)^2
\]

を採用する。\(P,Q\geq\varepsilon\) と \(p_0+q_0=2\) の制約は既存の exchange/active-set/GGLSE でそのまま解く。

このコストは数値上「振幅の 4 乗」の次元を持つが、必要な入力統計量は \(C_{xx},C_{yy}\) までであり、\(E[|X|^4]\) を観測・入力する必要はない。これは power-balance の代数残差を二乗しているためであり、確率変数 \(|X|^2\) 自体の期待二乗を評価しているわけではない。

周波数ごとの絶対パワーに拘束力を左右されたくない場合は

\[
d_l=\operatorname{hypot}(C_{xx,l},C_{yy,l}),\qquad
\widetilde C_{xx,l}=C_{xx,l}/d_l,\quad
\widetilde C_{yy,l}=C_{yy,l}/d_l
\]

という projective normalization が使える。ただしこれは既存の決定変数版に対して重みを \(w_l/d_l^2\) へ変更することと同じで、現在の「分散ゼロなら同一解」という契約を、そのままでは壊す。よって内部で暗黙には行わない。必要なら両 adapter に共通の明示的な normalization policy として追加する。

### 3.3 複素振幅推定量から power を観測する場合

推定誤差 \((e_X,e_Y)\) が jointly proper complex Gaussian であるとする。観測 power

\[
U=|\widehat X|^2,\qquad V=|\widehat Y|^2
\]

は非心 \(\chi^2\) 型であり、正規分布ではない。しかし必要な二次までの power moments、すなわち振幅についての四次モーメントは、Isserlis の関係から厳密に求められる。

\[
E[U]=|\mu_X|^2+v_X,qquad
\operatorname{Var}(U)=v_X^2+2v_X|\mu_X|^2,
\]

\[
E[V]=|\mu_Y|^2+v_Y,qquad
\operatorname{Var}(V)=v_Y^2+2v_Y|\mu_Y|^2,
\]

\[
\operatorname{Cov}(U,V)
=|c_{xy}|^2
+2\operatorname{Re}(\mu_X^*c_{xy}\mu_Y).
\]

推定誤差 power を目標値に混ぜたくなければ

\[
\widetilde U=U-v_X,qquad \widetilde V=V-v_Y
\]

を coherent power の不偏推定量として用いる。定数を引くだけなので分散・共分散は上式と同じであり、

\[
E[\widetilde U]=|\mu_X|^2,qquad
E[\widetilde V]=|\mu_Y|^2
\]

となる。したがって power 観測ベクトルとその covariance は、独立な四次統計量を追加観測しなくても、複素振幅の平均・分散・共分散だけから構成できる。

ただし、ここから選ぶ損失には差がある。

#### Expected squared power residual

\[
E[(P\widetilde U-Q\widetilde V)^2]
\]

は \(P,Q\) に関する二次形式なので、Gaussian closure で得た moment matrix を平方根分解すれば一回の constrained LS にできる。これは「ワット数推定の二乗誤差」という Bayes risk として正当である。

一方で、この式の分散項は不確かな bin の寄与を小さくするのではなく、\(P,Q\) に対する追加 penalty になる。したがって「推定分散が大きい bin を弱く拘束する」という要求とは同一ではない。

#### 非心 \(\chi^2\) と最小二乗の関係

Vonesh は、応答分布を完全には指定せず、平均と分散関数だけをモデル化する
quasi-likelihood を §4.1.1 で導入している（提供 PDF pp. 159--161）。その
quasi-score は平均ゼロで、分散と期待微分が一致するという通常の likelihood
score と共通の性質を持つ。相関応答については §4.2.1 で GEE へ拡張され、これは
明示的に non-likelihood semiparametric estimation と位置づけられている（提供 PDF
pp. 164--170）。また QELS は normality を必要としない LS 型推定として説明されて
いる（提供 PDF p. 169）。したがって、power が非心 \(\chi^2\) 型であることだけを
理由に二次損失を棄却する必要はない。

ただし、この一般論から現行 Power Fit が GEE と同じ一致性を持つとは結論できない。
GEE1 は平均残差を中心とする estimating equation

\[
D^T\Sigma^{-1}(z-\mu(\theta))=0
\]

を解き、平均モデルが正しければ working covariance の誤指定下でも一致性を得る
構成である（提供 PDF pp. 165--171）。これに対し現行 Power Fit は

\[
E[(P\widetilde U-Q\widetilde V)^2]
=(P\mu_U-Q\mu_V)^2
+P^2\sigma_U^2+Q^2\sigma_V^2-2PQ\sigma_{UV}
\]

を直接最小化する。真の平均関係 \(P\mu_U-Q\mu_V=0\) を満たす係数でも分散項は
残るため、有限の推定分散では、平均関係から少し外れて分散 penalty を小さくする
係数が選ばれ得る。したがって現行法の正確な位置づけは、Gaussian likelihood でも
quasi-score/GEE1 でもなく、**二次モーメントだけで定義した expected quadratic-risk
minimization** である。

この違いは次のように扱う。

- 目的が「不確かな power 推定値に対する期待二乗誤差最小化」なら、現行目的関数は
  power の非 Gaussian 性にかかわらず厳密である。proper complex Gaussian の振幅
  誤差から導いた power の平均・分散・共分散も厳密であり、power を Gaussian 近似
  してはいない。
- 目的が「潜在する平均 power 関係から真のプラント係数を一致推定すること」なら、
  現行目的関数は一般に有限分散 bias を持ち得る。上流の標本数増加に伴って
  \(K_l\to0\) となる場合には決定変数版へ収束するが、分散が消えない漸近系では
  GEE/EIV/likelihood 型の別目的関数が必要になる。
- 非心 \(\chi^2\) likelihood を直接使えば分布効率を狙えるが、相関した二つの power
  の差は単一の \(\chi^2\) ではなく相関した非心二次形式であり、通常は現在の固定行列・
  一回の凸 constrained LS では解けない。

#### Errors-in-variables power likelihood

power 観測 \(z_l=(\widetilde U_l,\widetilde V_l)^T\) の covariance を \(K_l\) とし、制約直線の法線を

\[
n_l(P,Q)=\begin{bmatrix}P(t_l)&-Q(t_l)\end{bmatrix}^T
\]

とすると、Gaussian/delta 近似による直交 Mahalanobis residual は

\[
J_{\mathrm{EIV}}
=\sum_l
\frac{(n_l^Tz_l)^2}
{n_l^TK_ln_l}
\]

となる。これは分散が大きい方向の拘束を正しく弱め、\(K_{12}\) を通じて power covariance も使う。しかし分母が \(P,Q\) に依存するため、一般には一回の凸二次問題ではない。IRLS、generalized TLS、または likelihood optimization の領域になる。

現在の一回解法を維持するなら、次のいずれかを設計として明示する。

1. pilot \((P_0,Q_0)\) で \(n_l^TK_ln_l\) を固定した feasible GLS。
2. coherence などの係数非依存な scalar reliability \(\rho_l\) で近似する。
3. expected squared power residual を採用し、「downweight」ではなく Bayes risk を最小化すると定義する。

四次モーメントを使うこと自体ではなく、この三者が異なる推定問題であることが本質である。

### 3.4 上流が直接 \(G\) を推定する場合

Complex RLS/CTF が \(\widehat G\) とその推定分散 \(v_G\) を直接返すなら、\(X,Y\) の power を再構成する必要はない。Power Fit へ

\[
C_{xx}=1,qquad C_{yy}=|G|^2
\]

という projective pair を渡せばよい。

頻度論的に \(\widehat G=G+e_G\)、\(e_G\sim\mathcal{CN}(0,v_G)\) とみなすなら

\[
\widehat Z=|\widehat G|^2-v_G
\]

は \(|G|^2\) の不偏推定量であり、

\[
\operatorname{Var}(\widehat Z)
=v_G^2+2v_G|G|^2
\]

である。実装上は未知の \(|G|^2\) を \(\max(|\widehat G|^2-v_G,0)\) などの pilot で置き換え、\(P-\widehat ZQ\) の重みに使える。低 SNR で \(\widehat Z<0\) となることは estimator の破綻ではなく、不偏 power estimate が非負制約と両立しない有限標本現象である。必要なら非心 \(\chi^2\) likelihood または非負 shrinkage estimator を別途選ぶ。

もし \((\mu_G,v_G)\) が頻度論的な推定値と標準誤差ではなく、真の \(G\) に対する posterior moments なら、二乗誤差に対する Bayes estimator は

\[
E[|G|^2\mid\text{data}]=|\mu_G|^2+v_G
\]

になる。\(|\mu_G|^2\) を target として分散は reliability のみに使う現在の方針とは推定対象が異なるため、API ではこの意味論を混在させない。

## 4. 信頼度と平均化

raw periodogram は標本数を増やしても各 bin の相対分散が消えないため、直接 Power Fit へ入れない。Ljung は ETFE の分散が局所の noise-to-signal ratio に比例し、周波数方向の平滑化や反復実験の重み付き平均が必要であることを示す（提供 PDF pp. 239--252）。Tangirala も任意入力の ETFE が inconsistent であること、平滑化した spectral estimator と inverse-variance WLS が必要であることを述べる（提供 PDF pp. 1966--1992, Eqs. 20.54--20.59）。Spagnolini の WOSA の議論も、平均化による分散低下と周波数分解能・bias の交換を示す（提供 PDF pp. 405--408）。

よって raw spectral adapter は、少なくとも平滑化・平均化済みの \(\widehat S_l\) と、有効自由度または平均数を受けるべきである。信頼度の優先順位は次の通りとする。

1. EIV/GTLS または spectral likelihood から得た局所的な Fisher information / 漸近分散の逆数。
2. 既知雑音行列で whiten した後の signal-to-noise 固有値分離。
3. output-error model が妥当な場合に限る squared coherence \(\gamma^2\)。

正確な代数残差の分散は \(P,Q\) に依存するため、その逆分散重みは一般に IRLS になる。一回解法を優先する場合、\(\rho\) は上流で伝達関数に依存しない pilot estimate から固定する。coherence は有界で安定な proxy だが、両側雑音や相関雑音を whitening せずに使うと ML 重みにはならない。

正制約 \(P,Q>0\) は物理的妥当性と補間時の暴走防止には有効だが、periodogram の inconsistency や EIV bias は解消しない。耐雑音性は主に、スペクトル平均、coherent 成分の分離、EIV に合った重みから得る。

## 5. 実装上の責務分離

### 5.1 Power Fit の内部 primitive

決定変数版は、正確に観測された実 power 座標を受ける。

```swift
static func fit(
    power x: some AccelerateBuffer<Float64>,
    to y: some AccelerateBuffer<Float64>,
    frequency: some AccelerateBuffer<Float64>,
    weight: some AccelerateBuffer<Float64>,
    minimum: Float64,
    count: (b: Int, a: Int)
) -> Direct.ChebyshevPowerRational
```

意味は

\[
X_l=x_l=C_{xx,l},\qquad Y_l=y_l=C_{yy,l},
\qquad x_lP_l-y_lQ_l=0
\]

である。現在の `fit(X:Y:...)` と同じ primitive だが、`X`,`Y` が複素振幅ではなく power 座標であることを label で明示する。

確率変数版は、実 power 座標の平均と covariance を受ける。

```swift
static func fit(
    power x: (
        mean: some AccelerateBuffer<Float64>,
        variance: some AccelerateBuffer<Float64>
    ),
    to y: (
        mean: some AccelerateBuffer<Float64>,
        variance: some AccelerateBuffer<Float64>
    ),
    covariance: some AccelerateBuffer<Float64>,
    frequency: some AccelerateBuffer<Float64>,
    weight: some AccelerateBuffer<Float64>,
    minimum: Float64,
    count: (b: Int, a: Int)
) -> Direct.ChebyshevPowerRational
```

各 bin で

\[
m_l=\begin{bmatrix}E[X_l]\\E[Y_l]\end{bmatrix},\qquad
K_l=\begin{bmatrix}
\operatorname{Var}(X_l)&\operatorname{Cov}(X_l,Y_l)\\
\operatorname{Cov}(X_l,Y_l)&\operatorname{Var}(Y_l)
\end{bmatrix}
\]

を作り、既定の確率変数 Power Fit を

\[
J=\sum_l w_lE[(P_lX_l-Q_lY_l)^2]
=\sum_lw_l n_l^T(m_lm_l^T+K_l)n_l
\]

と定義する。2x2 PSD moment matrix を平方根分解すれば、各 bin 最大 2 行の design matrix となり、既存の正制約 solver をそのまま使える。

\(K_l=0\) なら moment matrix は \(m_lm_l^T\) という rank-1 行に縮退するので、決定変数版と全く同じ目的関数・解になる。この縮退関係を API とテストの契約にする。

この primitive が受ける covariance は **power 推定量の covariance** であって、複素振幅の covariance ではない。複素振幅またはプラント推定量からの変換は adapter の責務とする。

### 5.2 プラント \(G\) に対する公開 adapter

プラント推定から利用する主 API は、\(X,Y\) より \(G\) を直接受ける方が意味が明確である。

決定変数版は位相を必要としない。

```swift
static func fit(
    gainSquared g²: some AccelerateBuffer<Float64>,
    frequency: some AccelerateBuffer<Float64>,
    weight: some AccelerateBuffer<Float64>,
    minimum: Float64,
    count: (b: Int, a: Int)
) -> Direct.ChebyshevPowerRational
```

内部では \((x,y)=(1,g^2)\) とする。数値的には

\[
(x,y)=\frac{(1,g^2)}{\operatorname{hypot}(1,g^2)}
\]

と projective normalization し、絶対 power scale を `weight` に混入させない方がよい。この normalization は既存 `fit(X:Y:)` の意味を変えるため、新しい plant-level adapter に限定するか、両決定変数 API で明示的に統一する。最初の実装では \((1,g^2)\) のままとし、normalization policy を後から両版へ同時に加えてもよい。

確率変数版は「ランダムなプラント」ではなく、固定プラントに対する複素推定値とその推定誤差分散を受ける。

```swift
static func fit(
    gain g: (
        r: some AccelerateBuffer<Float64>,
        i: some AccelerateBuffer<Float64>,
        errorVariance: some AccelerateBuffer<Float64>
    ),
    frequency: some AccelerateBuffer<Float64>,
    weight: some AccelerateBuffer<Float64>,
    minimum: Float64,
    count: (b: Int, a: Int)
) -> Direct.ChebyshevPowerRational
```

ここで

\[
\widehat G_l=G_l+e_l,\qquad
e_l\sim\mathcal{CN}(0,v_{G,l})
\]

という frequentist な sampling model を採用する。`errorVariance` という label にして、真の \(G\) の事前分散・時間変動・出力 residual power と混同しない。

adapter は例えば

\[
\widehat z_l=|\widehat G_l|^2-v_{G,l},
\qquad
\tau_l^2=v_{G,l}^2+2v_{G,l}|G_l|^2
\]

から gain-power estimate と sampling variance を作り、未知の \(|G_l|^2\) は非負 pilot で置き換えて

\[
X_l=1,\quad \operatorname{Var}(X_l)=0,
\qquad
Y_l\simeq\widehat z_l,\quad \operatorname{Var}(Y_l)\simeq\tau_l^2
\]

として確率変数 primitive へ渡す。`errorVariance == 0` では \(\widehat z=|\widehat G|^2\)、\(\tau^2=0\) となり、`gainSquared: |G|²` の決定変数版へ厳密に縮退する。

projective normalization を有効にする場合は、pilot から固定した \(d_l=\operatorname{hypot}(1,\widehat z_l)\) を決定変数版・確率変数版の双方に用い、平均を \(1/d_l,\widehat z_l/d_l\)、power covariance を \(1/d_l^2\) 倍する。確率変数版だけに normalization を加えてはならない。

\(\widehat z<0\) になり得るため、非負 projection、非心 \(\chi^2\) MLE、posterior shrinkage のどれを採るかは adapter policy として明示する。黙って `abs` を取ってはならない。

この三要素だけで十分なのは、推定誤差が frequency-bin ごとに独立な proper complex Gaussian の場合である。improper な誤差には pseudo-variance、bin 間相関を使うには対角 buffer ではなく周波数全体の covariance/operator が追加で必要になる。

すでに gain-power 推定量が得られている利用箇所には、複素変換を迂回する convenience も置ける。

```swift
static func fit(
    gainSquared g²: (
        estimate: some AccelerateBuffer<Float64>,
        errorVariance: some AccelerateBuffer<Float64>
    ),
    frequency: some AccelerateBuffer<Float64>,
    weight: some AccelerateBuffer<Float64>,
    minimum: Float64,
    count: (b: Int, a: Int)
) -> Direct.ChebyshevPowerRational
```

ここで `errorVariance` は \(\operatorname{Var}(\widehat{|G|^2}-|G|^2)\) であり、複素 \(G\) の error variance とは次元も数値も異なる。

### 5.3 上流 estimator が提供すべき量

`CTF.Snapshot` の stochastic Power Fit 用情報は

```swift
transfer: Array<Complex128>
transferErrorVariance: Array<Float64>
```

を基本とする。現在の `residualPower` は観測方程式の残差 power であって、そのまま \(\operatorname{Var}(\widehat G-G)\) ではない。

- RLS では、残差分散と inverse normal matrix から transfer の線形汎関数の分散を作る。係数を \(h\)、評価ベクトルを \(s\) とすれば、概ね \(\operatorname{Var}(s^Th)=\widehat\sigma_e^2s^HPs\) である。現在 C core が保持する inverse normal matrix だけでは出力残差分散による scale が未反映なので、両者を組み合わせる。
- H1 では output-error 仮定の下で \(\widehat G=S_{yx}/S_{xx}\) とし、平均化数・window の有効自由度と \(S_{vv}/S_{xx}\) から transfer variance を作る。`coherenceSquared` は有用な診断値だが、variance 自体の代用にはしない。
- 両側 EIV では H1 の `transfer` と variance だけでは bias を表現できない。既知雑音スペクトル行列を用いる GTLS/ML estimator が \(\widehat G\) とその covariance を返した後に、同じ `gain:` adapter へ接続する。

### 5.4 共有する内部処理

推奨する処理境界は次の通りである。

1. plant estimator が \(\widehat G\) と transfer error covariance を推定する。
2. plant adapter が gain-power の平均・分散へ変換する。
3. power-moment builder が各 2x2 moment matrix を実 design rows へ平方根分解する。
4. positive Power solver が design matrix だけを受け、\(P,Q\geq\varepsilon\) を解く。

raw `Sxx/Syy/Syx` overload を Power Fit 本体に直接増やすより、H1/EIV estimator を経由して `gain:` adapter に集約する方が、観測モデルと rational approximation の責務を分離できる。raw spectrum overload を設ける場合も、それは `error: .outputOnly` や既知雑音行列を必要とする estimator convenience と位置づける。

## 6. 検証すべき性質

- \(v_X=v_Y=c_{xy}=0\) の RLS adapter が決定変数版と同じ設計行列・解を返す。
- output-error simulation で raw \(S_{yy}/S_{xx}\) より \(|S_{xy}|^2/S_{xx}^2\) が真の \(|G|^2\) に収束する。
- 両側雑音 simulation で H1 が bias を持ち、既知 \(N\) による whitened rank-1 extraction/GTLS がその bias を抑える。
- 同じ期待スペクトルで平均数だけを変えたとき、有効自由度を使う重みの分散が予測どおり変わる。
- coherence が低い bin を増やしても fit が不安定化せず、情報のある bin が支配する。
- \(P,Q\geq\varepsilon\) は全区間で維持されるが、正制約だけでは EIV bias が消えないことも確認する。

## 参考文献

### 提供された文献（本文を確認）

- Edward F. Vonesh, [*Generalized Linear and Nonlinear Models for Correlated Data: Theory and Applications Using SAS*](https://learning.oreilly.com/library/view/-/9781599946474/), SAS Institute, 2012, book。[提供 PDF](<./Generalized Linear and Nonlinear Models for Correlated Data_ Theory and Applications Using SAS.pdf>) pp. 157--171（§4.1.1--4.2.2）を確認。完全な分布指定を要しない quasi-likelihood、相関応答に対する GEE、normality を要しない QELS、および working covariance と robust inference の位置づけの根拠。
- Lennart Ljung, [*System Identification: Theory for the User, 2nd Edition*](https://learning.oreilly.com/library/view/-/9780132441933/), Pearson Education, 1998-12-29, book（本文上は Prentice Hall, 1999）。[提供 PDF](<./System Identification_ Theory for the User 2nd Edition.pdf>) pp. 233--256（§6.3--6.4）を確認。ETFE、spectral analysis、inverse-variance weighting、disturbance spectrum、coherency の根拠。
- Arun K. Tangirala, [*Principles of System Identification*](https://learning.oreilly.com/library/view/-/9781439895993/), CRC Press, 2014-12-19, book（本文上は 2015）。[提供 PDF](<./Principles of System Identification.pdf>) pp. 974--980（§11.4）および pp. 1965--1998（§20.4.2--20.5）を確認。coherence--SNR 関係、ETFE の inconsistency、平滑化スペクトル比と漸近分散の根拠。
- Umberto Spagnolini, [*Statistical Signal Processing in Engineering*](https://learning.oreilly.com/library/view/-/9781119293972/), Wiley, 2018-02-05, book。[提供 PDF](<./Statistical Signal Processing in Engineering.pdf>) pp. 399--415（§14.1.4--14.2.2）および pp. 629--635（§20.3.2）を確認。periodogram の分布、WOSA、Gaussian spectral likelihood/Whittle approximation、coherence-based weighting の根拠。

### 追加の一次文献

- P. R. White, M. H. Tan and J. K. Hammond, “Analysis of the maximum likelihood, total least squares and principal component approaches for frequency response function estimation,” *Journal of Sound and Vibration*, 290(3--5), 2006. [DOI](https://doi.org/10.1016/j.jsv.2005.04.029). 両側加法雑音に対する ML、TLS/PCA、generalized TLS の比較。
- E. Zhang and R. Pintelon, “Frequency domain maximum likelihood identification of linear dynamic errors-in-variables systems with arbitrary unknown noise covariance,” *Automatica*, 93, 2018. [DOI](https://doi.org/10.1016/j.automatica.2018.04.039). 両側 EIV の識別性、FRF と雑音分散の consistent estimation。
- A. M. Sykulski et al., “The De-Biased Whittle Likelihood,” arXiv:1306.5993. [arXiv](https://arxiv.org/abs/1306.5993). 有限標本 bias を考慮した Whittle likelihood の位置づけ。
- J. Shaman, “The inverted complex Wishart distribution and its application to spectral estimation,” *Journal of Multivariate Analysis*, 10(1), 1980. [DOI](https://doi.org/10.1016/0047-259X(80)90081-0). 平均化 spectral matrix と complex-Wishart 統計の根拠。
